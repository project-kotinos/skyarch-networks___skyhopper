var queryString    = require('query-string').parse(location.search);
var Infrastructure = require('models/infrastructure').default;
var EC2Instance    = require('models/ec2_instance').default;
var pdfMake      = require('pdfmake/build/pdfmake.js');
var fontsMap    = require('../modules/fonts_map.js');
pdfMake.fonts = fontsMap;
var tableRender    = require('../modules/table_render');
var helpers = require('infrastructures/helper.js');
var alert_success  = helpers.alert_success;

module.exports = Vue.extend({
  template: '#view-rules-tabpane-template',

  props: {
    physical_id: {
      type: String,
      required: true,
    },
    security_groups: {
      type: Array,
      required: true,
    },
    instance_type:{
      type: String,
      required: true,
    },
    infra_id: {
      type: Number,
      required: true,
    },
  },

  data: function () { return{
    loading:        false,
    rules_summary:  null,
    ip: null,
    lang: queryString.lang,
    table_data: [[]],
  };},

  methods: {
    get_rules: function ()  {
      var self = this;
      var group_ids = [];
      var infra = new Infrastructure(self.infra_id);
      var ec2 = new EC2Instance(infra, this.physical_id);
      self.security_groups.forEach(function (value, key) {
        if(self.instance_type === 'elb' || self.instance_type === 'rds'){
          if(value.checked)
            group_ids.push(value.group_id);
        }else{
          group_ids.push(value.group_id);
        }
      });

      ec2.get_rules(group_ids).done(function (data) {
        self.rules_summary = data.rules_summary;
        var records = [];

        self.rules_summary.forEach(function (rule) {
          var row_length = Math.max(rule.ip_permissions.length,rule.ip_permissions_egress.length,1);
          for(var i = 0 ; i < row_length ; i++) {
            var record = [];
            if(i === 0) {
              record.push({text: rule.description, row: row_length, th: true});
              record.push({text: rule.group_id, row: row_length, th: true});
            }
            if (rule.ip_permissions[i]) {
              record.push({text: rule.ip_permissions[i].prefix_list_ids, row: 1});
              record.push({text: rule.ip_permissions[i].ip_protocol, row: 1});
              record.push({text: rule.ip_permissions[i].to_port, row: 1});
              record.push({text: rule.ip_permissions[i].ip_ranges.map(x => x.cidr_ip).join(', '), row: 1});
            } else {
              record.push({text: '', row: 1});
              record.push({text: '', row: 1});
              record.push({text: '', row: 1});
              record.push({text: '', row: 1});
            }
            if (rule.ip_permissions_egress[i]) {
              record.push({text: rule.ip_permissions_egress[i].prefix_list_ids, row: 1});
              record.push({text: rule.ip_permissions_egress[i].ip_protocol, row: 1});
              record.push({text: rule.ip_permissions_egress[i].to_port, row: 1});
              record.push({text: rule.ip_permissions_egress[i].ip_ranges[0].cidr_ip, row: 1});
            } else {
              record.push({text: '', row: 1});
              record.push({text: '', row: 1});
              record.push({text: '', row: 1});
              record.push({text: '', row: 1});
            }
            records.push(record);
          }
        });
        self.table_data = records;
      });
    },

    show_ec2: function () {
      if(this.instance_type === 'elb'){
        this.$parent.show_elb(this.physical_id);
      }else if (this.instance_type === 'rds') {
        this.$parent.show_rds(this.physical_id);
      }else{
        this.$parent.show_ec2(this.physical_id);
      }
    },
    print_pdf: function(){
      if (!pdfMake.vfs) {
        alert_success()(t('js.infrastructures.msg.fonts_loading_in_progress'));
        return;
      }

      var data = this.rules_summary;
      var defaultFont = Object.keys(fontsMap)[0];

      var docDefinition = {
        footer: function(currentPage, pageCount) {
          return {
            text: currentPage.toString() + ' of ' + pageCount
          };
        },
        content: [
          {
            text: t('security_groups.title'),
            style: 'header',
            alignment: 'center'
          },
          {
            text: [t('infrastructures.stackname')+': ', { text: this.$parent.$data.current_infra.stack.name+'\n',  bold: true}],
            alignment: 'left'
          },
          {
            text: [t('infrastructures.physical_id')+': ', { text: this.physical_id.toString()+'\n',  bold: true}],
            alignment: 'left'
          },
          {
            text: [t('infrastructures.date')+': ', { text: moment().format('YYYY-MM-DD, HH:mm:ss')+'\n',  bold: true}],
            alignment: 'left'
          },
          tableRender(data)
        ],
        styles: {
          header: {
            fontSize: 16,
            bold: true,
            margin: [0, 0, 0, 10]
          },
          subheader: {
            fontSize: 14,
            bold: true,
            margin: [0, 10, 0, 5]
          },
          tableExample: {
            margin: [5, 5, 0, 15]
          },
          tableHeader: {
            bold: true,
            fontSize: 11,
            color: 'black'
          },
        },
        defaultStyle: {
          // alignment: 'justify'
          fontSize: 10,
          alignment: 'center',
          font: defaultFont
        },
        pageSize: 'A4',
        pageOrientation: 'landscape',
        pageMargins: [15, 30, 20, 30 ]

      };

      pdfMake.createPdf(docDefinition).open();

      this.get_rules();
    },
    check_length: function(args){
      return args.length > 0;
    },
  },
  mounted: function (){
    this.$nextTick(function () {
    console.log(this);
    this.get_rules();
    this.$parent.loading = false;
    })
  },
});
