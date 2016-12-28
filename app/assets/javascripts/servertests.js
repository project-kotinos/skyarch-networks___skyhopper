//
// Copyright (c) 2013-2016 SKYARCH NETWORKS INC.
//
// This software is released under the MIT License.
//
// http://opensource.org/licenses/mit-license.php
//

//browserify functions for vue filters functionality
var wrap = require('./modules/wrap');
var listen = require('./modules/listen');
var queryString = require('query-string').parse(location.search);
var modal = require('modal');
var app;

Vue.component('demo-grid', require('demo-grid.js'));
var servertest_url = queryString.infrastructure_id ? 'infrastructure_id='+queryString.infrastructure_id: '';

var servertestIndex = new Vue({
  el: '#indexElement',
  data: {
    searchQuery: '',
    gridColumns: ['servertest_name','description', 'category'],
    gridData: [],
    index: 'servertests',
    picked: {
        servertest_path: null,
        edit_servertest_path: null
    },
    infra_id: queryString.infrastructure_id ? '&infrastructure_id='+queryString.infrastructure_id: '',
    url: 'servertests?'+servertest_url,
    is_empty: false,
    loading: true,
  },
    methods: {
      can_edit: function() {
        return this.picked.edit_servertest_path === null ? true : false;
      },
      can_delete: function() {
        return (this.picked.servertest_path === null) ? true: false;
      },
      delete_entry: function()  {
        var self = this;
        console.log(self.picked.servertest_path);
        modal.Confirm(t('servertests.servertest'), t('servertests.msg.delete_servertest'), 'danger').done(function () {
          $.ajax({
            type: "POST",
            url: self.picked.servertest_path,
            dataType: "json",
            data: {"_method":"delete"},
            success: function (data) {
                location.reload();
            },
        }).fail(modal.AlertForAjaxStdError());
        });
      },
      reload: function () {
        this.loading = true;
        this.$children[0].load_ajax(this.url);
        this.picked = {};
      },
      show_servertest: function(servertest_id) {
        $.ajax({
          url : "/servertests/" + servertest_id,
          type : "GET",
          success : function (data) {
            $("#value-information").html(data);
          }
        });
        document.getElementById('value').style.display='';
      }
    },
});



require("serverspec-gen");
