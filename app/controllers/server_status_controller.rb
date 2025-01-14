#
# Copyright (c) 2013-2017 SKYARCH NETWORKS INC.
#
# This software is released under the MIT License.
#
# http://opensource.org/licenses/mit-license.php
#

class ServerStatusController < ApplicationController
  before_action :authenticate_user!
  before_action :set_server
  after_action :watch_server_state, only: [:start, :stop]


  # POST /server/:kind/start
  # @param [String] kind Server kind. "zabbix"
  def start
    @server.start

    render nothing: true
  end

  # POST /server/:kind/stop
  # @param [String] kind Server kind. "zabbix"
  def stop
    @server.stop

    render nothing: true
  end

  # POST /server/:kind/status
  # @param [String] kind Server kind. "zabbix"
  # @param [Boolean] background If this is true, server status updated background.
  def status
    unless params[:background] || @server.is_in_progress?
      render text: @server.status and return
    end

    render text: @server.latest_status and return
  end


  private

  def set_server
    @server = ServerState.new(params.require(:kind))
  end

  def watch_server_state
    ServerStateWorker.perform_now(@server.kind)
  end
end
