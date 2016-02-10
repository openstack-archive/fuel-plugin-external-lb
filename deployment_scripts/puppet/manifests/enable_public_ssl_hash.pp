# This is a workaround to disable adding record to hosts file if we use
# FQDN external public host
notice('MODULAR: external_loadbalancer/enable_public_ssl_hash.pp')

$plugin_name = 'external_loadbalancer'
$external_lb = hiera("$plugin_name")
$ssl_hash    = hiera_hash('use_ssl', {})

if empty($ssl_hash) and !is_ip_address($external_lb['external_public_vip']){
  notice('Removing hiera override which disables adding of $public_vip to /etc/hosts')
  file {'/etc/hiera/override/configuration/cluster.yaml':
    ensure => present,
  }
  file_line { 'public_ssl_line':
    ensure => absent,
    path   => '/etc/hiera/override/configuration/cluster.yaml',
    line   => 'public_ssl: {}',
  }
} else {
  notice('Doing nothing')
}
