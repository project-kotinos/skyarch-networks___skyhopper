//
// Copyright (c) 2013-2016 SKYARCH NETWORKS INC.
//
// This software is released under the MIT License.
//
// http://opensource.org/licenses/mit-license.php
//

(function () {
  Vue.component('div-loader', Loader);
  const modal = require('modal');

  const kpvm = new Vue({
    el: '#key-pairs-page',
    data: {
      selected: 'All',
      loading: true,
      pages: 10,
      pageNumber: 0,
      key_pairs: [],
      project_id: '',
      regions: null,
      filterKey: '',
      selected_key_pairs: null,
    },
    methods: {
      switch_region(region_name) {
        if (this.number_of_key_pairs(region_name) === 0) { return; }

        const selected = this.selected;
        _.find(this.regions, region => region.name === selected).selected = false;

        this.selected = region_name;

        _.find(this.regions, region => region.name === region_name).selected = true;
        this.pageNumber = 0;
      },
      key_pairs_by_region(region_name) {
        return _.select(this.key_pairs, key_pair => key_pair.region === region_name);
      },
      number_of_key_pairs(region_name) {
        if (region_name === 'All') {
          return this.key_pairs.length;
        }
        return this.key_pairs_by_region(region_name).length;
      },
      has_no_key_pairs(region_name) {
        return this.number_of_key_pairs(region_name) === 0;
      },
      is_selected(region_name) {
        return this.selected === 'All' || this.selected === region_name;
      },
      delete_key_pair(key_pair) {
        const self = this;

        modal.Confirm(t('key_pairs.key_pairs'), t('key_pairs.msg.confirm', { name: key_pair.name })).done(() => {
          $.ajax({
            type: 'DELETE',
            url: `/key_pairs/${key_pair.fingerprint}`,
            data: {
              project_id: self.project_id,
              region: key_pair.region,
            },
          }).done(() => {
            const index = self.key_pairs.indexOf(key_pair);
            $(`.table > tbody > tr:nth-child(${index + 1})`).fadeOut('normal', () => {
              const index = self.key_pairs.indexOf(key_pair);
              self.key_pairs.splice(index, 1);
              if (self.has_no_key_pairs(key_pair.region)) {
                self.switch_region('All');
              }
            });
          });
        });
      },
      reload() {
        const self = this;
        self.loading = true;
        self.key_pairs = [];
        $.ajax({
          url: `/key_pairs/retrieve${location.search}`,
        }).done((data) => {
          self.project_id = data.project_id;
          self.key_pairs = data.key_pairs;
          _.forEach(data.key_pairs, (key_pair) => {
            key_pair.using_sign = key_pair.using ? '✔' : '';
          });
          self.selected = 'All';
          self.regions = [{
            name: 'All',
            selected: true,
          }];
          _.forEach(data.regions, (region) => {
            self.regions.push({
              name: region,
              selected: false,
            });
          });
          self.loading = false;
        });
      },
      showPrev() {
        if (this.pageNumber === 0) return;
        this.pageNumber--;
      },
      showNext() {
        if (this.isEndPage) return;
        this.pageNumber++;
      },
      roundup(val) { return (Math.ceil(val)); },

      zero_as_blank(num) {
        return (num === 0) ? null : num;
      },
    },
    computed: {
      isStartPage() {
        return (this.pageNumber === 0);
      },
      isEndPage() {
        return ((this.pageNumber + 1) * this.pages >= this.number_of_key_pairs(this.selected));
      },
      check_length() {
        if (this.selected_key_pairs) {
          return (this.selected_key_pairs.length >= 10);
        }
      },
      filterd_keys() {
        const self = this;
        const items = this.key_pairs.filter((data) => {
          if (self.filterKey === '') {
            return true;
          }
          return JSON.stringify(data).toLowerCase().indexOf(self.filterKey.toLowerCase()) !== -1;
        });
        self.filteredLength = items.length;
        return items;
      },
    },
    created() {
      this.reload();
    },
    mounted() {
      this.$nextTick(function () {
        console.log(this.key_pairs);
      });
    },
    filters: {
      paginate(list) {
        const self = this;
        const index = this.pageNumber * this.pages;
        const isSelected = [];
        if (self.selected !== 'All') {
          list.forEach((value, key) => {
            if (value.region === self.selected) {
              isSelected.push(value);
            }
          });
          this.selected_key_pairs = isSelected;
          return isSelected.slice(index, index + this.pages);
        }
        this.selected_key_pairs = list;
        return list.slice(index, index + this.pages);
      },

    },
  });
}());
