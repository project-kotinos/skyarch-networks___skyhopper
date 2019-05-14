#
# Copyright (c) 2013-2017 SKYARCH NETWORKS INC.
#
# This software is released under the MIT License.
#
# http://opensource.org/licenses/mit-license.php
#

module ApplicationHelper
  def full_title(page_title)
    base_title = 'SkyHopper' # to set up their own application name
    if page_title.empty?
      base_title
    else
      "#{base_title} | #{page_title} "
    end
  end

  def gravatar(email)
    require 'digest/md5'
    email_address = email.downcase
    hash = Digest::MD5.hexdigest(email_address)
    image_src = "https://secure.gravatar.com/avatar/#{hash}"

    image_tag(image_src, size: '24x24', class: 'img-rounded gravatar-icon')
  end

  def bootstrap_flash(options = {})
    flash_messages = []
    if Rails.cache.exist?(:err)
      flash[:danger] = Rails.cache.read(:err)
      Rails.cache.delete(:err)
    end
    flash.each do |type, message|
      # Skip empty messages, e.g. for devise messages set to nothing in a locale file.
      next if message.blank?

      type = type.to_sym
      type = :success if type.to_s == :notice.to_s
      type = :danger if type.to_s == :alert.to_s

      Array(message).each do |msg|
        text = content_tag(:div,
                           content_tag(:button, raw('&times;'), :class => 'close', 'data-dismiss' => 'alert') + msg,
                           class: "alert fade in alert-#{type} alert-dismissible #{options[:class]}",)
        flash_messages << text if msg
      end
    end
    flash_messages.join("\n").html_safe
  end

  def breadcrumbs(client = nil, project = nil, infrastructure = nil)
    breadcrumb = '<ul class="breadcrumb">'

    breadcrumb <<
      if client
        <<~TEMPLATE
          <li><a href="#{clients_path}">#{client.name} (#{client.code})</a></li>
        TEMPLATE
      else
        <<~TEMPLATE
          <li><a href="#{clients_path}">#{I18n.t('clients.client')}</a></li>
        TEMPLATE
      end

    if project
      breadcrumb << <<~TEMPLATE
        <li><a href="#{projects_path(client_id: client.id)}">#{project.name} (#{project.code})</a></li>
      TEMPLATE
    elsif client
      breadcrumb << <<~TEMPLATE
        <li class="active">#{I18n.t('projects.project')}</li>
      TEMPLATE
    end

    if infrastructure
      breadcrumb << <<~TEMPLATE
        <li class="active">#{infrastructure.stack_name}</li>
      TEMPLATE
    elsif project
      breadcrumb << <<~TEMPLATE
        <li class="active">#{I18n.t('infrastructures.infrastructure')}</li>
      TEMPLATE
    end

    breadcrumb << '</ul>'

    breadcrumb.html_safe
  end

  def loading_with_message(message = nil)
    loading_tag = '<div class="loader"></div>'.html_safe

    loading_tag <<
      if message
        " #{message}"
      else
        t('common.msg.loading')
      end

    loading_tag
  end

  def uneditable_input(content)
    "<span class=\"input-large uneditable-input form-control\" readonly>#{content}</span>".html_safe
  end

  def admin_label
    '<span class="label label-info">admin</span>'.html_safe
  end

  def master_label
    '<span class="label label-warning">master</span>'.html_safe
  end

  def add_option_path(path, options)
    options_str = options.map { |key, val| "#{key}=#{val}" }.join('&')
    "#{path}?#{options_str}"
  end

  def glyphicon(name = nil)
    return false unless name

    "<span class=\"glyphicon glyphicon-#{name}\"></span>".html_safe
  end

  def fa(name = nil)
    return false unless name

    "<span class=\"fa fa-#{name}\"></span>".html_safe
  end
end
