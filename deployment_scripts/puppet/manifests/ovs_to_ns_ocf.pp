notice('MODULAR: external_loadbalancer/ovs_to_ns_ocf.pp')

$plugin_name    = 'external_loadbalancer'
$external_lb    = hiera("$plugin_name")
$network_scheme = hiera_hash("network_scheme", {})
$floating_br    = pick($network_scheme['roles']['neutron/floating'], 'br-floating')
$floating_gw_if = pick($external_lb['floating_gw_if'], 'exlb-float-gw')

if $external_lb['external_public_vip'] and $external_lb['enable_fake_floating'] {
  file {'/usr/lib/ocf/resource.d/fuel/ovs_to_ns_port':
    ensure => file,
    mode   => '0755',
    source => "puppet:///modules/external_loadbalancer/ovs_to_ns_port",
  }
}
