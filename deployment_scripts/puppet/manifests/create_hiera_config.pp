# Manifest that creates hiera config overrride
notice('MODULAR: external_loadbalancer/create_hiera_config.pp')

$plugin_name    = 'external_loadbalancer'
$external_lb    = hiera("$plugin_name")
$network_scheme = hiera_hash("network_scheme", {})
$floating_br    = pick($network_scheme['roles']['neutron/floating'], 'br-floating')
$floating_gw_if = pick($external_lb['floating_gw_if'], 'exlb-float-gw')
$master_ip      = hiera('master_ip')

file {"/etc/hiera/plugins/${plugin_name}.yaml":
  ensure  => file,
  content => inline_template("# Created by puppet, please do not edit manually
network_metadata:
  vips:
<% if @external_lb['external_management_vip'] -%>
    management:
      ipaddr: <%= @external_lb['management_ip'] %>
      namespace: false
<% if @external_lb['skip_vrouter_vip'] -%>
    vrouter:
      namespace: false
      ipaddr: <%= @master_ip %>
<% end -%>
<% end -%>
<% if @external_lb['external_public_vip'] -%>
    public:
      ipaddr: <%= @external_lb['public_ip'] %>
      namespace: false
<% if @external_lb['skip_vrouter_pub_vip'] -%>
    vrouter_pub:
      namespace: false
<% end -%>
run_ping_checker: false
<% end -%>
<% if @external_lb['external_public_vip'] and @external_lb['enable_fake_floating'] -%>
quantum_settings:
  predefined_networks:
    admin_floating_net:
      L3:
        subnet: <%= @external_lb['fake_floating_cidr'] %>
        floating:
        - <%= @external_lb['fake_floating_range'] %>
        gateway: <%= @external_lb['fake_floating_gw'] %>
<% end -%>
")
}
