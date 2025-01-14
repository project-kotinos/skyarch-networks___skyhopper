//
// Copyright (c) 2013-2016 SKYARCH NETWORKS INC.
//
// This software is released under the MIT License.
//
// http://opensource.org/licenses/mit-license.php
//
(function () {
  'use_strict';

  // browserify functions for vue filters functionality
  const wrap = require('./modules/wrap');
  const listen = require('./modules/listen');
  const queryString = require('query-string').parse(location.search);
  const modal = require('modal');
  let app;

  Vue.component('demo-grid', require('demo-grid.js'));

  if ($('#indexElement').length) {
    new Vue({
      el: '#indexElement',
      data: {
        searchQuery: '',
        gridColumns: ['code', 'name'],
        gridData: [],
        lang: queryString.lang,
        url: `clients?lang=${queryString.lang}`,
        is_empty: false,
        loading: true,
        picked: {
          edit_client_path: null,
          code: null,
        },
        index: 'clients',
      },
      computed: {
        can_edit() {
          if (this.picked.edit_client_path) return !!this.picked.edit_client_path;
        },
        can_delete() {
          if (this.picked.code) return (this.picked.code[1] === 0);
        },
      },
      methods: {

        delete_entry() {
          const self = this;
          modal.Confirm(t('clients.client'), t('clients.msg.delete_client'), 'danger').done(() => {
            $.ajax({
              type: 'POST',
              url: self.picked.delete_client_path,
              dataType: 'json',
              data: { _method: 'delete' },
              success(data) {
                self.gridData = data;
                self.picked = {};
              },
            }).fail(() => {
              location.reload();
            });
          });
        },
        reload() {
          this.loading = true;
          this.$children[0].load_ajax(this.url);
          this.picked = {};
        },

      },
    });
  }
}());
