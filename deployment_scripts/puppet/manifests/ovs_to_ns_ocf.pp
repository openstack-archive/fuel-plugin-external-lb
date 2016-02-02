notice('MODULAR: external_loadbalancer/ovs_to_ns_ocf.pp')

$plugin_name    = 'external_loadbalancer'
$external_lb    = hiera("$plugin_name")
$network_scheme = hiera_hash("network_scheme", {})
$floating_br    = pick($network_scheme['roles']['neutron/floating'], 'br-floating')
$floating_gw_if = pick($external_lb['floating_gw_if'], 'exlb-float-gw')

if $external_lb['external_public_vip'] and $external_lb['enable_fake_floating'] {
  $service_name = 'p_exlb_floating_port'
  $primitive_type = 'ovs_to_ns_port'
  $complex_type   = 'clone'
  $ms_metadata = {
    'interleave' => true,
  }
  $metadata = {
    'migration-threshold' => 'INFINITY',
    'failure-timeout'     => '120',
  }
  $parameters = {
    'ns'                  => 'vrouter',
    'ovs_interface'       => $floating_br,
    'namespace_interface' => $floating_gw_if,
    'namespace_ip'        => $external_lb['fake_floating_gw'],
    'namespace_cidr'      => $external_lb['fake_floating_cidr'],
  }
  $operations = {
    'monitor' => {
      'interval' => '60',
      'timeout'  => '120'
    },
    'start'   => {
      'timeout' => '30'
    },
    'stop'    => {
      'timeout' => '30'
    },
  }

  file {'/usr/lib/ocf/resource.d/fuel/ovs_to_ns_port':
    ensure => file,
    mode   => '0755',
    source => "puppet:///modules/external_loadbalancer/ovs_to_ns_port",
  }

  service { $service_name :
    ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    provider   => 'pacemaker',
    require    => File['/usr/lib/ocf/resource.d/fuel/ovs_to_ns_port'],
  }

  pacemaker_wrappers::service { $service_name :
    primitive_type => $primitive_type,
    parameters     => $parameters,
    metadata       => $metadata,
    operations     => $operations,
    ms_metadata    => $ms_metadata,
    complex_type   => $complex_type,
    prefix         => false,
    require        => File['/usr/lib/ocf/resource.d/fuel/ovs_to_ns_port'],
  }
}
