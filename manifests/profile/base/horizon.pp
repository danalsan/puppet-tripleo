# Copyright 2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# == Class: tripleo::profile::base::horizon
#
# Horizon profile for tripleo
#
# === Parameters
#
# [*step*]
#   (Optional) The current step in deployment. See tripleo-heat-templates
#   for more details.
#   Defaults to hiera('step')
#
# [*bootstrap_node*]
#   (Optional) The hostname of the node responsible for bootstrapping tasks
#   Defaults to hiera('bootstrap_nodeid')
#
# [*neutron_options*]
#   (Optional) A hash of parameters to enable features specific to Neutron
#   Defaults to hiera('horizon::neutron_options', {})
#
# [*memcached_ips*]
#   (Optional) Array of ipv4 or ipv6 addresses for memcache.
#   Defaults to hiera('memcached_node_ips')
#
class tripleo::profile::base::horizon (
  $step            = Integer(hiera('step')),
  $bootstrap_node  = hiera('bootstrap_nodeid', undef),
  $neutron_options = hiera('horizon::neutron_options', {}),
  $memcached_ips   = hiera('memcached_node_ips')
) {
  if $::hostname == downcase($bootstrap_node) {
    $is_bootstrap = true
  } else {
    $is_bootstrap = false
  }

  if $step >= 4 or ( $step >= 3 and $is_bootstrap ) {
    # Horizon
    include ::apache::mod::remoteip
    include ::apache::mod::status
    if 'cisco_n1kv' in hiera('neutron::plugins::ml2::mechanism_drivers', undef) {
      $_profile_support = 'cisco'
    } else {
      $_profile_support = 'None'
    }
    $neutron_options_real = merge({'profile_support' => $_profile_support }, $neutron_options)

    if is_ipv6_address($memcached_ips[0]) {
        $horizon_memcached_servers = prefix(any2array(normalize_ip_for_uri($memcached_ips)), 'inet6:')

    } else {
        $horizon_memcached_servers = any2array(normalize_ip_for_uri($memcached_ips))
    }

    class { '::horizon':
      cache_server_ip => $horizon_memcached_servers,
      neutron_options => $neutron_options_real,
    }
  }
}
