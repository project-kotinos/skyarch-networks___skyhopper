//
// Copyright (c) 2013-2016 SKYARCH NETWORKS INC.
//
// This software is released under the MIT License.
//
// http://opensource.org/licenses/mit-license.php
//

/// <reference path="../../declares.d.ts" />

import ModelBase      from './base';
import Infrastructure from './infrastructure';

export default class RDSInstance extends ModelBase {
  private params: {physical_id: string, id: string};

  constructor(private infra: Infrastructure, private physical_id: string) {
    super();
    this.params = {
      physical_id: physical_id,
      id:          infra.id,
    };
  }

  static ajax_infra = new AjaxSet.Resources('infrastructures');
  static ajax_serverspec = new AjaxSet.Resources('serverspecs');


  show(): JQueryPromise<any> {
    return this.WrapAndResolveReject(() =>
      (<any>RDSInstance.ajax_infra).show_rds(this.params)
    );
  }

  change_scale(type: string): JQueryPromise<any> {
    return this.WrapAndResolveReject(() =>
      (<any>RDSInstance.ajax_infra).change_rds_scale(
        _.merge(this.params, {instance_type: type})
      )
    );
  }

  gen_serverspec(parameter: any): JQueryPromise<any> {
    return this.WrapAndResolveReject(() =>
      (<any>RDSInstance.ajax_serverspec).create_for_rds(
        _.merge({physical_id: this.physical_id, infra_id: this.infra.id}, parameter)
      )
    );
  }

  rds_submit_groups(group_ids: Array<any>): JQueryPromise<any> {
    return this.WrapAndResolveReject(() =>
      (<any>RDSInstance.ajax_infra).rds_submit_groups(_.merge(this.params, {group_ids: group_ids}))
    );
  }

  start_rds(): JQueryPromise<any> {
    return this.WrapAndResolveReject(() =>
      (<any>RDSInstance.ajax_infra).start_rds(this.params)
    );
  }

  stop_rds(): JQueryPromise<any> {
    return this.WrapAndResolveReject(() =>
      (<any>RDSInstance.ajax_infra).stop_rds(this.params)
    );
  }

  reboot_rds(): JQueryPromise<any> {
    return this.WrapAndResolveReject(() =>
      (<any>RDSInstance.ajax_infra).reboot_rds(this.params)
    );
  }
}

RDSInstance.ajax_infra.add_member('show_rds', 'GET');
RDSInstance.ajax_infra.add_member('change_rds_scale', 'POST');
RDSInstance.ajax_infra.add_member('rds_submit_groups', 'POST');
RDSInstance.ajax_infra.add_member('start_rds', 'POST');
RDSInstance.ajax_infra.add_member('stop_rds', 'POST');
RDSInstance.ajax_infra.add_member('reboot_rds', 'POST');

RDSInstance.ajax_serverspec.add_collection('create_for_rds', 'PUT');
