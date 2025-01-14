//
// Copyright (c) 2013-2016 SKYARCH NETWORKS INC.
//
// This software is released under the MIT License.
//
// http://opensource.org/licenses/mit-license.php
//

// Data is the Rules summary of the assigned security group for the instance_type

// Which contains inbound and outbound rules of the said security group
// The main contents are: description, group ID, inbound and outbound rules
/* Data eg.:
  data = {
    description: "fugafuga",
    group_id: "sg-4b30d72f",
    group_name: "hogehoge",
    ip_permissions: Array,
    ip_permissions_egress: Array
    vpc_id: "not used"
  }

*/
module.exports = function (data) {
  return {
    style: 'tableExample',
    color: '#444',
    table: {
      headerRows: 2,
      dontBreakRows: true,
      widths: [120, 90, 'auto', 'auto', 'auto', 100, 'auto', 'auto', 'auto', 100],
      body: buildTableBody(data),
    },
  };
};

function eval_port(from_port, to_port) {
  if (from_port && to_port) {
    return from_port === to_port ? from_port.toString() : `${from_port.toString()}-${to_port.toString()}`;
  }

  return 'All';
}

function eval_protocol(ip_protocol) {
  return ip_protocol === '-1' ? 'All' : ip_protocol;
}

function eval_source(ip, id) {
  if (ip.length > 0) {
    return ip[0].cidr_ip;
  }
  return id[0].group_id;
}

function buildTableBody(data) {
  const body = [];

  console.log(data);
  body.push([{ rowSpan: 2, text: t('security_groups.description'), style: 'tableHeader' },
    { rowSpan: 2, text: t('security_groups.group_id'), style: 'tableHeader' },
    { colSpan: 4, text: t('security_groups.inbound'), style: 'tableHeader' },
    'x', 'x', 'xx',
    { colSpan: 4, text: t('security_groups.outbound'), style: 'tableHeader' },
    'x', 'x', 'x'], ['x', 'x',
    { text: t('security_groups.type'), style: 'tableHeader' },
    { text: t('security_groups.protocol'), style: 'tableHeader' },
    { text: t('security_groups.port_range'), style: 'tableHeader' },
    { text: t('security_groups.source'), style: 'tableHeader' },
    { text: t('security_groups.type'), style: 'tableHeader' },
    { text: t('security_groups.protocol'), style: 'tableHeader' },
    { text: t('security_groups.port_range'), style: 'tableHeader' },
    { text: t('security_groups.source'), style: 'tableHeader' },
  ]);

  data.forEach((v, index) => {
    const inbound = v.ip_permissions;
    const outbound = v.ip_permissions_egress;

    push_initial(v, inbound, outbound, body);
    inbound.shift(); // Remove first index
    outbound.shift(); // Remove first index
    extract_next(inbound, outbound, body);
  });
  return body;
}

function push_initial(v, inbound, outbound, body) {
  // Check if inbound lenght is greater than outbound lenght
  if (inbound.length > outbound.length) {
    // If outbound has contents
    if (outbound.length > 0) {
      body.push([{ text: v.description, style: 'tableHeader', rowSpan: inbound.length },
        { text: v.group_id, style: 'tableHeader', rowSpan: inbound.length },
        inbound[0].prefix_list_ids,
        eval_protocol(inbound[0].ip_protocol),
        eval_port(inbound[0].from_port, inbound[0].to_port),
        eval_source(inbound[0].ip_ranges, inbound[0].user_id_group_pairs),
        outbound[0].prefix_list_ids,
        eval_protocol(outbound[0].ip_protocol),
        eval_port(outbound[0].from_port, outbound[0].from_port),
        eval_source(outbound[0].ip_ranges, outbound[0].user_id_group_pairs),
      ]);
      // Insert (-) if outbound doesn't exists
    } else {
      body.push([{ text: v.description, style: 'tableHeader', rowSpan: inbound.length },
        { text: v.group_id, style: 'tableHeader', rowSpan: inbound.length },
        inbound[0].prefix_list_ids,
        eval_protocol(inbound[0].ip_protocol),
        eval_port(inbound[0].from_port, inbound[0].to_port),
        eval_source(inbound[0].ip_ranges, inbound[0].user_id_group_pairs),
        '-', '-', '-', '-',
      ]);
    }
    // IF outbound length is greated than inbound
  } else if (inbound.length < outbound.length) {
    // Check if inbound has contents
    if (inbound.length > 0) {
      body.push([{ text: v.description, style: 'tableHeader', rowSpan: outbound.length },
        { text: v.group_id, style: 'tableHeader', rowSpan: outbound.length },
        inbound[0].prefix_list_ids,
        eval_protocol(inbound[0].ip_protocol),
        eval_port(inbound[0].from_port, inbound[0].to_port),
        eval_source(inbound[0].ip_ranges, inbound[0].user_id_group_pairs),
        outbound[0].prefix_list_ids,
        eval_protocol(outbound[0].ip_protocol),
        eval_port(outbound[0].from_port, outbound[0].from_port),
        eval_source(outbound[0].ip_ranges, outbound[0].user_id_group_pairs),
      ]);
    } else {
      body.push([{ text: v.description, style: 'tableHeader', rowSpan: outbound.length },
        { text: v.group_id, style: 'tableHeader', rowSpan: outbound.length },
        '-', '-', '-', '-',
        outbound[0].prefix_list_ids,
        eval_protocol(outbound[0].ip_protocol),
        eval_port(outbound[0].from_port, outbound[0].from_port),
        eval_source(outbound[0].ip_ranges, outbound[0].user_id_group_pairs),
      ]);
    }
    // Push blank
  } else if (inbound.length === outbound.length) {
    body.push([{ text: v.description, style: 'tableHeader', rowSpan: outbound.length },
      { text: v.group_id, style: 'tableHeader', rowSpan: outbound.length },
      inbound[0].prefix_list_ids,
      eval_protocol(inbound[0].ip_protocol),
      eval_port(inbound[0].from_port, inbound[0].to_port),
      eval_source(inbound[0].ip_ranges, inbound[0].user_id_group_pairs),
      outbound[0].prefix_list_ids,
      eval_protocol(outbound[0].ip_protocol),
      eval_port(outbound[0].from_port, outbound[0].from_port),
      eval_source(outbound[0].ip_ranges, outbound[0].user_id_group_pairs),
    ]);
  } else {
    body.push([{ text: v.description, style: 'tableHeader', rowSpan: outbound.length },
      { text: v.group_id, style: 'tableHeader', rowSpan: outbound.length },
      '-', '-', '-', '-', '-', '-', '-', '-',
    ]);
  }
}


function extract_next(inbound, outbound, body) {
  if (inbound.length > outbound.length) {
    inbound.forEach((v, index) => {
      if (outbound.length > index) {
        body.push(['', '',
          v.prefix_list_ids,
          eval_protocol(v.ip_protocol),
          eval_port(v.from_port, v.to_port),
          eval_source(v.ip_ranges, v.user_id_group_pairs),
          outbound[index].prefix_list_ids,
          eval_protocol(outbound[index].ip_protocol),
          eval_port(outbound[index].from_port, outbound[index].to_port),
          eval_source(outbound[index].ip_ranges, outbound[index].user_id_group_pairs),
        ]);
      } else {
        body.push(['', '',
          v.prefix_list_ids,
          eval_protocol(v.ip_protocol),
          eval_port(v.from_port, v.tp_port),
          eval_source(v.ip_ranges, v.user_id_group_pairs),
          '-',
          '-',
          '-',
          '-',
        ]);
      }
    });
  } else if (inbound.length === outbound.length) {
    inbound.forEach((v, index) => {
      body.push(['', '',
        v.prefix_list_ids,
        eval_protocol(v.ip_protocol),
        eval_port(v.from_port, v.to_port),
        eval_source(v.ip_ranges, v.user_id_group_pairs),
        outbound[index].prefix_list_ids,
        eval_protocol(outbound[index].ip_protocol),
        eval_port(outbound[index].from_port, outbound[index].to_port),
        eval_source(outbound[index].ip_ranges, outbound[index].user_id_group_pairs),
      ]);
    });
  } else {
    outbound.forEach((v, index) => {
      if (inbound.length > index) {
        body.push(['', '',
          inbound[index].prefix_list_ids,
          eval_protocol(inbound[index].ip_protocol),
          eval_port(inbound[index].from_port, inbound[index].to_port),
          eval_source(inbound[index].ip_ranges, inbound[index].user_id_group_pairs),
          v.prefix_list_ids,
          eval_protocol(v.ip_protocol),
          eval_port(v.from_port),
          eval_source(v.ip_ranges, v.user_id_group_pairs),
        ]);
      } else {
        body.push(['', '',
          '-',
          '-',
          '-',
          '-',
          v.prefix_list_ids,
          eval_protocol(v.ip_protocol),
          eval_port(v.from_port, v.to_port),
          eval_source(v.ip_ranges, v.user_id_group_pairs),
        ]);
      }
    });
  }
}
