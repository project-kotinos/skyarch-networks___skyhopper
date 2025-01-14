#
# Copyright (c) 2013-2017 SKYARCH NETWORKS INC.
#
# This software is released under the MIT License.
#
# http://opensource.org/licenses/mit-license.php
#

# for Ec2 instance

class Ec2InstancesController < ApplicationController
  include Concerns::InfraLogger


  # --------------- Auth
  before_action :authenticate_user!

  before_action do
    infra = Infrastructure.find(params.require(:infra_id))
    def infra.policy_class;Ec2InstancePolicy end
    authorize infra
  end

  # TODO: use websocket
  # POST /ec2_instances/i-0b8e7f12/change_scale
  def change_scale
    physical_id = params.require(:id)
    infra_id    = params.require(:infra_id)
    type        = params.require(:instance_type)
    infra       = Infrastructure.find(infra_id)

    instance = infra.instance(physical_id)
    before_type = instance.instance_type

    begin
      changed_type = instance.change_scale(type)
    rescue EC2Instance::ChangeScaleError => ex
      render text: ex.message, status: 400 and return
    end

    if changed_type == before_type
      #TODO: status code はこれでいい?
      render text: I18n.t('nodes.msg.not_change_scale', type: type), status: 200 and return
    end

    render text: I18n.t('nodes.msg.changed_scale', type: type) and return
  end

  # GET /ec2_instances/available_resources
  # @param [Integer] infra_id
  def available_resources
    infra_id = params.require(:infra_id)
    infra = Infrastructure.find(infra_id)

    items = infra.ec2.describe_instance_status[:instance_statuses]
    resp = []
    items.each do |item|
      unless infra.resources.where(physical_id: item[:instance_id]).exists?
        resp.push({physical_id: item[:instance_id]})
      end
    end

    render json: resp and return
  end

  # TODO: return ec2 status
  # XXX: DRY (Ref: ServerStateConroller)

  # POST /ec2_instances/i-hogehoge/start
  def start
    physical_id = params.require(:id)
    infra_id    = params.require(:infra_id)

    instance = Infrastructure.find(infra_id).instance(physical_id)
    instance.start
    infra_logger_success("#{physical_id} is turned on the power.")

    notify_ec2_status(instance, :running)

    render text: I18n.t('ec2_instances.msg.start_ec2')
  end

  # POST /ec2_instances/i-hogehoge/stop
  def stop
    physical_id = params.require(:id)
    infra_id    = params.require(:infra_id)

    instance = Infrastructure.find(infra_id).instance(physical_id)
    instance.stop
    infra_logger_success("#{physical_id} is turned off the power.")

    notify_ec2_status(instance, :stopped)

    render text: I18n.t('ec2_instances.msg.stop_ec2')
  end

  # POST /ec2_instances/i-hogehoge/detach
  def detach
    physical_id = params.require(:id)
    zabbix = params.require(:zabbix)
    resource = Resource.find_by(physical_id: physical_id)

    if zabbix == "true"
      resource.detach_zabbix
    end

    resource.destroy

    infra_logger_success("#{physical_id} has been detached.")

    notify_ec2_status(resource, :detached)

    render text: I18n.t('ec2_instances.msg.detach_ec2')
  end

  # POST /ec2_instances/i-hogehoge/terminate
  def terminate
    physical_id = params.require(:id)
    infra_id    = params.require(:infra_id)

    instance = Infrastructure.find(infra_id).instance(physical_id)
    instance.terminate
    resource = Resource.find_by(physical_id: physical_id)
    resource.detach_zabbix
    resource.destroy

    infra_logger_success("#{physical_id} has been terminated.")

    notify_ec2_status(instance, :terminated)

    render text: I18n.t('ec2_instances.msg.terminate_ec2')
  end

  # POST /ec2_instances/i-hogehoge/reboot
  # XXX: reboot しても status が変わらない気がする?
  def reboot
    physical_id = params.require(:id)
    infra_id    = params.require(:infra_id)

    Infrastructure.find(infra_id).instance(physical_id).reboot
    infra_logger_success("#{physical_id} start reboot.")

    render nothing: true
  end


  # GET /ec2_instances/:id/serverspec_status
  # @param [String] id ec2 instance physical_id
  # @param [String] infra_id Infrastructure id
  # @return [String] JSON. {status: Boolean}
  def serverspec_status
    physical_id = params.require(:id)
    status = ! Resource.find_by(physical_id: physical_id).status.servertest.failed?

    render json: {status: status}
  end


  # POST /ec2_instances/:id/register_to_elb
  # @param [String] id physical_id of ec2 instance
  # @param [String] elb_name ELB name
  # @param [String] infra_id ID of Infrastructure
  def register_to_elb
    physical_id = params.require(:id)
    elb_name    = params.require(:elb_name)
    infra_id    = params.require(:infra_id)

    infra = Infrastructure.find(infra_id)
    elb   = ELB.new(infra, elb_name)

    elb.register(physical_id)

    render text: I18n.t('ec2_instances.msg.registered_to_elb')
  end

  # POST /ec2_instances/:id/deregister_to_elb
  # @param [String] id physical_id of ec2 instance
  # @param [String] elb_name ELB name
  # @param [String] infra_id ID of Infrastructure
  def deregister_from_elb
    physical_id = params.require(:id)
    elb_name    = params.require(:elb_name)
    infra_id    = params.require(:infra_id)

    infra = Infrastructure.find(infra_id)
    elb   = ELB.new(infra, elb_name)

    elb.deregister(physical_id)

    render text: I18n.t('ec2_instances.msg.deregistered_from_elb')
  end

  # POST /ec2_instances/:id/elb_submit_groups
  # @param [Array] security groups array
  # @param [String] elb_name ELB name
  # @param [String] infra_id ID of Infrastructure
  def elb_submit_groups
    elb_name    = params.require(:elb_name)
    infra_id    = params.require(:infra_id)
    group_ids   = params.require(:group_ids)

    infra = Infrastructure.find(infra_id)
    elb   = ELB.new(infra, elb_name)

    elb.elb_submit_groups(group_ids)

    render text: I18n.t('security_groups.msg.change_success')
  end


  def attachable_volumes
    physical_id       = params.require(:id)
    infra_id          = params.require(:infra_id)
    availability_zone = params.require(:availability_zone)

    instance = Infrastructure.find(infra_id).instance(physical_id)
    volumes = instance.attachable_volumes(availability_zone)

    render json: {attachable_volumes: volumes}
  end

  def attach_volume
    physical_id = params.require(:id)
    infra_id    = params.require(:infra_id)
    volume_id   = params.require(:volume_id)
    device_name = params.require(:device_name)

    instance = Infrastructure.find(infra_id).instance(physical_id)
    resp = instance.attach_volume(volume_id, device_name)

    render json: resp
  end

  def detach_volume
    physical_id = params.require(:id)
    infra_id    = params.require(:infra_id)
    volume_id   = params.require(:volume_id)

    instance = Infrastructure.find(infra_id).instance(physical_id)
    resp = instance.detach_volume(volume_id)

    render text: t('ec2_instances.msg.volume_detached', resp.to_h)
  end

  def create_volume
    infra_id          = params.require(:infra_id)
    physical_id       = params.require(:id)

    options = {
      availability_zone: params.require(:availability_zone),
      snapshot_id:       params[:snapshot_id],
      volume_type:       params[:volume_type],
      size:              params[:size].to_i,
      encrypted:         params[:encrypted],
    }
    options[:iops] = params[:iops] if options[:volume_type] == 'io1'

    infra    = Infrastructure.find(infra_id)
    instance = infra.instance(physical_id)
    resp = instance.create_volume(options)

    render text: t('ec2_instances.msg.creating_volume', resp.to_h)
  end

  private

  def notify_ec2_status(instance, status)
    Thread.new_with_db do
      ws = WSConnector.new('ec2_status', instance.physical_id)
      begin
        instance.wait_status(status)
        ws.push_as_json(error: nil, msg: "#{instance.physical_id} status is #{status}")
      rescue => ex
        ws.push_error(ex)
      end
    end
  end
end
