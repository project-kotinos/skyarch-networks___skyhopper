# -*- coding: utf-8 -*-
#
# Copyright (c) 2013-2017 SKYARCH NETWORKS INC.
#
# This software is released under the MIT License.
#
# http://opensource.org/licenses/mit-license.php
#

class MonitoringsController < ApplicationController
  # TODO: auth

  include Concerns::InfraLogger

  before_action :authenticate_user!

  before_action :set_infra

  before_action do
    def @infra.policy_class;MonitoringPolicy;end
    authorize(@infra)
  end

  before_action :with_zabbix, expect: [:show_cloudwatch_graph]
  before_action :set_zabbix, except: [:show_cloudwatch_graph]


  # GET /monitorings/:id
  def show
    # XXX: 一つでも登録されていたら監視をshowするようになってるけど、いい?
    if @infra.resources.ec2.none?{|r| @zabbix.host_exists?(r.physical_id)}
      # すべてのec2が登録されていなければ
      # Only show those hosts that are registered
      @before_register = true

      #get/load available zabbix templates set to static first.
      @templates = @zabbix.available_templates.map{|t| {name: t, checked: false}}
      return
    end

    @monitor_selected_common   = @infra.master_monitorings.where(is_common: true)
    @monitor_selected_uncommon = @infra.master_monitorings.where(is_common: false)


    linked_resources = []
    resources = @infra.resources.ec2
    resources.each do |item|
      merged = []
      linked = @zabbix.get_linked_templates(item.physical_id)
      unlinked = @zabbix.available_templates
      if linked
        unlinked.each do |link|
          if linked.include?(link)
            merged.push({name: link, checked: true})
          else
            merged.push({name: link, checked: false})
          end
        end
        linked_resources.push({resource: item.physical_id, templates: merged, linked: true})
      else
        unlinked.each do |d|
          merged.push({name: d, checked: false})
        end
        linked_resources.push({resource: item.physical_id, templates: merged, linked: false})
      end
    end


    @linked_resources = linked_resources

    @resources = @infra.resources.ec2

  end

  # POST /monitorings/:id/update_templates
  def update_templates
    physical_id = params.require(:physical_id)
    new_templates = params.require(:templates)
    prev_templates = @zabbix.get_linked_templates(physical_id)
    if prev_templates
      clear_templates = []

      # compare if the previous templates was removed and push to clear list
      prev_templates.each do |prev|
        if new_templates.include?(prev)
          # new_templates.pop(prev)
        else
          clear_templates.push(prev)
        end
      end

      @zabbix.templates_update_host(physical_id, new_templates, clear_templates)
      infra_logger_success("#{physical_id} Templates Updated!")
    else
      z = @zabbix
      begin
        if z.version.start_with?('2')
          reqs = []
          z.create_host(@infra, physical_id)

          # TODO: Batch request
          reqs.push z.templates_link_host_build(physical_id, new_templates)
          item_info_cpu   = z.create_cpu_usage_item(physical_id)
          item_info_mysql = z.create_mysql_login_item(physical_id)
          reqs.push z.create_cpu_usage_trigger_build(  item_info_cpu,   physical_id)
          reqs.push z.create_mysql_login_trigger_build(item_info_mysql, physical_id)
          z.batch(*reqs)
        else
          z.create_host(@infra, physical_id)
          z.templates_link_host(physical_id, new_templates)
          item_info_cpu   = z.create_cpu_usage_item(physical_id)
          item_info_mysql = z.create_mysql_login_item(physical_id)
          z.create_cpu_usage_trigger(  item_info_cpu,   physical_id)
          z.create_mysql_login_trigger(item_info_mysql, physical_id)
        end
      rescue => ex
        @infra.detach_zabbix()

        render text: ex.message, status: 500 and return
      end

      @zabbix.templates_link_host(physical_id, new_templates)
      infra_logger_success("#{physical_id} is linked to Zabbix!")
    end

      render nothing: true and return

  end

  # GET /monitorings/:id/show_cloudwatch_graph
  def show_cloudwatch_graph
    physical_id = params.require(:physical_id)

    cw = CloudWatch.new(@infra)
    # the average of data every 5 mins. 1 minute -> costs
    cloudwatch_stats = cw.get_networkinout(physical_id)

    render json: cloudwatch_stats
  end

  # GET /monitorings/show_zabbix_graph
  def show_zabbix_graph
    physical_id = params.require(:physical_id)
    item_key    = params.require(:item_key)
    date_range  = params[:date_range]

    # TODO: I18n
    unless @infra.resources.pluck(:physical_id).include?(physical_id)
      raise 'Invalid access!'
    end

    z = @zabbix

    if item_key == "mysql.login"
      item_infos = z.get_item_info(physical_id, item_key, 'search')
      item_key = item_infos.first["key_"]
    end

    history_all = z.get_history(physical_id, item_key, date_range)

    render json: history_all
  end

  # GET /monitorings/:id/show_problems
  def show_problems
    recent_problems = @zabbix.show_recent_problems(@infra)

    render json: recent_problems
  end

  # GET /monitorings/:id/show_url_status
  def show_url_status
    url_status = @zabbix.get_url_status_monitoring(@infra)

    render json: url_status
  end


  # GET /monitorings/:id/edit
  def edit
    z = @zabbix
    if @infra.resources.ec2.none?{|r| z.host_exists?(r.physical_id)}
      # XXX: workaround?
      render nothing: true, status: 400 and return
    end

    @master_monitorings = MasterMonitoring.all
    @selected_monitoring_ids = @infra.monitorings.pluck(:master_monitoring_id)

    hostname = @infra.resources.ec2.first.physical_id
    @trigger_expressions = z.get_trigger_expressions_by_hostname(hostname)
    @web_scenarios = z.all_web_scenarios(@infra)
    @zabbix_servers = ZabbixServer.selected_zabbix(@zabbix_server.id)
  end

  # PUT /monitorings/:id
  def update
    web_scenario    = JSON.parse(params.require(:web_scenario))
    monitoring_ids  = params[:monitoring_ids]
    # hash -> {master_monitoring_id: expr num}
    expr_nums       = JSON.parse(params[:expressions])
    # hash -> {master_monitoring_id: rds_hostname}
    host_mysql      = JSON.parse(params[:host_mysql])
    # host_postgresql = JSON.parse(params[:host_postgresql])

    @infra.master_monitoring_ids = monitoring_ids
    master_monitorings = MasterMonitoring.all

    monitorings_selected = []
    trigger_exprs = {}
    master_monitorings.each do |monitoring|
      if @infra.master_monitorings.include?(monitoring)
        monitorings_selected.push(monitoring.item)
      end

      # ハッシュのキーを置換えて新しく作成しなおしている
      # {master_monitoring_id: expr_num(数字だけ)} -> {item_key: expressions(式)}
      expr_nums.each do |k, v|
        if k.to_i == monitoring.id
          new_k = monitoring.item
          new_v = monitoring.trigger_expression + v.to_s
          trigger_exprs[new_k] = new_v
          break
        end
      end
    end

    z = @zabbix

    #TODO infra.eachをここでまとめる
    z.switch_trigger_status(@infra, monitorings_selected)
    z.create_web_scenario(@infra, web_scenario)

    # zabbix側でmysqlに関するitemとtrigger expressionをアップデートする
    z.update_mysql(@infra, host_mysql["host"])

    # if there are any triggers to update then do so
    if expr_nums.present?
      z.update_trigger_expression(@infra, trigger_exprs)
    end

    infra_logger_success("Monitoring Options updated")

    # TODO: Zabbix Server側の状態の更新
    render text: I18n.t('monitoring.msg.updated')
  end

  # POST /monitorings/:id/create_host
  def create_host
    templates = params.require(:templates)
    resources = @infra.resources.ec2

    z = @zabbix

    begin
      if z.version.start_with?('2')
        reqs = []
        resources.each do |resource|
          z.create_host(@infra, resource.physical_id)

          # TODO: Batch request
          reqs.push z.templates_link_host_build(resource.physical_id, templates)
          item_info_cpu   = z.create_cpu_usage_item(resource.physical_id)
          item_info_mysql = z.create_mysql_login_item(resource.physical_id)
          reqs.push z.create_cpu_usage_trigger_build(  item_info_cpu,   resource.physical_id)
          reqs.push z.create_mysql_login_trigger_build(item_info_mysql, resource.physical_id)
        end
        reqs.push z.create_elb_host_build(@infra)
        z.batch(*reqs)
      else
        resources.each do |resource|
          z.create_host(@infra, resource.physical_id)
          z.templates_link_host(resource.physical_id, templates)
          item_info_cpu   = z.create_cpu_usage_item(resource.physical_id)
          item_info_mysql = z.create_mysql_login_item(resource.physical_id)
          z.create_cpu_usage_trigger(  item_info_cpu,   resource.physical_id)
          z.create_mysql_login_trigger(item_info_mysql, resource.physical_id)
        end
        z.create_elb_host(@infra)
      end
    rescue => ex
      @infra.detach_zabbix()

      render text: ex.message, status: 500 and return
    end

    infra_logger_success("Infrastructure is registered to Zabbix")
    render nothing: true and return
  end

  # POST /monitorings/:id/change_zabbix_server
  # PARAMS Selected Zabbix server ID
  def change_zabbix_server
    zabbix_id = params.require(:zabbix_id)
    @infra.project.change_zabbix(zabbix_id, current_user)
    @infra.project.save!

    infra_logger_success("Zabbix Server Changed!")
    render nothing: true and return
  end


  private

  def set_infra
    @infra = Infrastructure.find(params.require(:id))
  end

  def set_zabbix
    @zabbix_server = @infra.project.zabbix_server
    raise t('projects.msg.zabbix_not_set') unless @zabbix_server
    @zabbix = Zabbix.new(@zabbix_server.fqdn, current_user.email, current_user.encrypted_password)
  end
end
