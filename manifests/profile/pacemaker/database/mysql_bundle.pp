# Copyright 2017 Red Hat, Inc.
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
# == Class: tripleo::profile::pacemaker::mysql_bundle
#
# Containerized Mysql Pacemaker HA profile for tripleo
#
# === Parameters
#
# [*mysql_docker_image*]
#   (Optional) The docker image to use for creating the pacemaker bundle
#   Defaults to hiera('tripleo::profile::pacemaker::database::mysql_bundle::mysql_docker_image', undef)
#
# [*control_port*]
#   (Optional) The bundle's pacemaker_remote control port on the host
#   Defaults to hiera('tripleo::profile::pacemaker::database::mysql_bundle::control_port', '3123')
#
# [*bootstrap_node*]
#   (Optional) The hostname of the node responsible for bootstrapping tasks
#   Defaults to hiera('mysql_short_bootstrap_node_name')
#
# [*bind_address*]
#   (Optional) The address that the local mysql instance should bind to.
#   Defaults to $::hostname
#
# [*ca_file*]
#   (Optional) The path to the CA file that will be used for the TLS
#   configuration. It's only used if internal TLS is enabled.
#   Defaults to undef
#
# [*certificate_specs*]
#   (Optional) The specifications to give to certmonger for the certificate
#   it will create. Note that the certificate nickname must be 'mysql' in
#   the case of this service.
#   Example with hiera:
#     tripleo::profile::base::database::mysql::certificate_specs:
#       hostname: <overcloud controller fqdn>
#       service_certificate: <service certificate path>
#       service_key: <service key path>
#       principal: "mysql/<overcloud controller fqdn>"
#   Defaults to hiera('tripleo::profile::base::database::mysql::certificate_specs', {}).
#
# [*enable_internal_tls*]
#   (Optional) Whether TLS in the internal network is enabled or not.
#   Defaults to hiera('enable_internal_tls', false)
#
# [*gmcast_listen_addr*]
#   (Optional) This variable defines the address on which the node listens to
#   connections from other nodes in the cluster.
#   Defaults to hiera('mysql_bind_host')
#
# [*pcs_tries*]
#   (Optional) The number of times pcs commands should be retried.
#   Defaults to hiera('pcs_tries', 20)
#
# [*step*]
#   (Optional) The current step in deployment. See tripleo-heat-templates
#   for more details.
#   Defaults to hiera('step')
#
#
class tripleo::profile::pacemaker::database::mysql_bundle (
  $mysql_docker_image  = hiera('tripleo::profile::pacemaker::database::mysql_bundle::mysql_docker_image', undef),
  $control_port        = hiera('tripleo::profile::pacemaker::database::mysql_bundle::control_port', '3123'),
  $bootstrap_node      = hiera('mysql_short_bootstrap_node_name'),
  $bind_address        = $::hostname,
  $ca_file             = undef,
  $certificate_specs   = hiera('tripleo::profile::base::database::mysql::certificate_specs', {}),
  $enable_internal_tls = hiera('enable_internal_tls', false),
  $gmcast_listen_addr  = hiera('mysql_bind_host'),
  $pcs_tries           = hiera('pcs_tries', 20),
  $step                = Integer(hiera('step')),
) {
  if $::hostname == downcase($bootstrap_node) {
    $pacemaker_master = true
  } else {
    $pacemaker_master = false
  }

  $galera_node_names_lookup = hiera('mysql_short_node_names', $::hostname)
  $galera_fqdns_names_lookup = hiera('mysql_node_names', $::hostname)

  if is_array($galera_node_names_lookup) {
    $galera_nodes = downcase(join($galera_fqdns_names_lookup, ','))
  } else {
    $galera_nodes = downcase($galera_node_names_lookup)
  }
  $galera_nodes_array = split($galera_nodes, ',')
  $galera_nodes_count = count($galera_nodes_array)

  # construct a galera-pacemaker name mapping for the resource agent
  # [galera-bundle-0:galera_node[0], galera-bundle-1:galera_node[1], ... ,galera-bundle-n:galera_node[n]]
  $host_map_array = $galera_nodes_array.map |$i, $host| {
    "galera-bundle-${i}:${host}"
  }
  $cluster_host_map_string = join($host_map_array, ';')

  if $enable_internal_tls {
    $tls_certfile = $certificate_specs['service_certificate']
    $tls_keyfile = $certificate_specs['service_key']
    if $ca_file {
      $tls_ca_options = "socket.ssl_ca=${ca_file}"
    } else {
      $tls_ca_options = ''
    }
    $tls_options = "socket.ssl_key=${tls_keyfile};socket.ssl_cert=${tls_certfile};${tls_ca_options};"
  } else {
    $tls_options = ''
  }

  $mysqld_options = {
    'mysqld' => {
      'pid-file'                      => '/var/lib/mysql/mariadb.pid',
      'skip-name-resolve'             => '1',
      'binlog_format'                 => 'ROW',
      'default-storage-engine'        => 'innodb',
      'innodb_autoinc_lock_mode'      => '2',
      'innodb_locks_unsafe_for_binlog'=> '1',
      'innodb_file_per_table'         => 'ON',
      'query_cache_size'              => '0',
      'query_cache_type'              => '0',
      'bind-address'                  => $bind_address,
      'max_connections'               => hiera('mysql_max_connections'),
      'open_files_limit'              => '-1',
      'wsrep_on'                      => 'ON',
      'wsrep_provider'                => '/usr/lib64/galera/libgalera_smm.so',
      'wsrep_cluster_name'            => 'galera_cluster',
      'wsrep_cluster_address'         => "gcomm://${galera_nodes}",
      'wsrep_slave_threads'           => '1',
      'wsrep_certify_nonPK'           => '1',
      'wsrep_max_ws_rows'             => '131072',
      'wsrep_max_ws_size'             => '1073741824',
      'wsrep_debug'                   => '0',
      'wsrep_convert_LOCK_to_trx'     => '0',
      'wsrep_retry_autocommit'        => '1',
      'wsrep_auto_increment_control'  => '1',
      'wsrep_drupal_282555_workaround'=> '0',
      'wsrep_causal_reads'            => '0',
      'wsrep_sst_method'              => 'rsync',
      'wsrep_provider_options'        => "gmcast.listen_addr=tcp://${gmcast_listen_addr}:4567;${tls_options}",
    },
    'mysqld_safe' => {
      'pid-file'                      => '/var/lib/mysql/mariadb.pid',
    }
  }

  # remove_default_accounts parameter will execute some mysql commands
  # to remove the default accounts created by MySQL package.
  # We need MySQL running to run the commands successfully, so better to
  # wait step 2 before trying to run the commands.
  if $step >= 2 and $pacemaker_master {
    $remove_default_accounts = true
  } else {
    $remove_default_accounts = false
  }

  if $step >= 1 and $pacemaker_master and hiera('stack_action') == 'UPDATE' {
    tripleo::pacemaker::resource_restart_flag { 'galera-master':
      subscribe => File['mysql-config-file'],
    }
  }

  $mysql_root_password = hiera('mysql::server::root_password')

  if $step >= 1 {
    # Kolla sets the root password, expose it to the MySQL package
    # so that it can initialize the database (e.g. create users)
    file { '/root/.my.cnf' :
      ensure  => file,
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => "[client]
user=root
password=\"${mysql_root_password}\"

[mysql]
user=root
password=\"${mysql_root_password}\"",
    }

    # Resource agent uses those credentials to poll galera state
    file { '/etc/sysconfig/clustercheck' :
      ensure  => file,
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      content => "MYSQL_USERNAME=root\n
MYSQL_PASSWORD='${mysql_root_password}'\n
MYSQL_HOST=localhost\n",
    }
  }

  if $step >= 2 {
    # need that class to create all openstack credentials
    # we don't include it in step 1 because the kolla bootstrap
    # happens after step 1 baremetal
    class { '::tripleo::profile::base::database::mysql':
      bootstrap_node          => $bootstrap_node,
      manage_resources        => false,
      remove_default_accounts => $remove_default_accounts,
      mysql_server_options    => $mysqld_options,
    }

    if $pacemaker_master {
      $mysql_short_node_names = hiera('mysql_short_node_names')
      $mysql_short_node_names.each |String $node_name| {
        # lint:ignore:puppet-lint-2.0.1 does not work with multiline strings
        # and blocks (remove this when we move to 2.2.0 where this works)
        pacemaker::property { "galera-role-${node_name}":
          property => 'galera-role',
          value    => true,
          tries    => $pcs_tries,
          node     => $node_name,
          before   => Pacemaker::Resource::Bundle['galera-bundle'],
        }
        # lint:endignore
      }

      $storage_maps = {
        'mysql-cfg-files'   => {
          'source-dir' => '/var/lib/kolla/config_files/mysql.json',
          'target-dir' => '/var/lib/kolla/config_files/config.json',
          'options'    => 'ro',
        },
        'mysql-cfg-data'    => {
          'source-dir' => '/var/lib/config-data/puppet-generated/mysql/',
          'target-dir' => '/var/lib/kolla/config_files/src',
          'options'    => 'ro',
        },
        'mysql-hosts'       => {
          'source-dir' => '/etc/hosts',
          'target-dir' => '/etc/hosts',
          'options'    => 'ro',
        },
        'mysql-localtime'   => {
          'source-dir' => '/etc/localtime',
          'target-dir' => '/etc/localtime',
          'options'    => 'ro',
        },
        'mysql-lib'         => {
          'source-dir' => '/var/lib/mysql',
          'target-dir' => '/var/lib/mysql',
          'options'    => 'rw',
        },
        'mysql-log-mariadb' => {
          'source-dir' => '/var/log/mariadb',
          'target-dir' => '/var/log/mariadb',
          'options'    => 'rw',
        },
        'mysql-dev-log'     => {
          'source-dir' => '/dev/log',
          'target-dir' => '/dev/log',
          'options'    => 'rw',
        },
      }

      if $enable_internal_tls {
        $mysql_storage_maps_tls = {
          'mysql-pki-gcomm-key'  => {
            'source-dir' => '/etc/pki/tls/private/mysql.key',
            'target-dir' => '/var/lib/kolla/config_files/src-tls/etc/pki/tls/private/mysql.key',
            'options'    => 'ro',
          },
          'mysql-pki-gcomm-cert' => {
            'source-dir' => '/etc/pki/tls/certs/mysql.crt',
            'target-dir' => '/var/lib/kolla/config_files/src-tls/etc/pki/tls/certs/mysql.crt',
            'options'    => 'ro',
          },
        }
        if $ca_file {
          $ca_storage_maps_tls = {
            'mysql-pki-gcomm-ca' => {
              'source-dir' => $ca_file,
              'target-dir' => "/var/lib/kolla/config_files/src-tls${ca_file}",
              'options'    => 'ro',
            },
          }
        } else {
          $ca_storage_maps_tls = {}
        }
        $storage_maps_tls = merge($mysql_storage_maps_tls, $ca_storage_maps_tls)
      } else {
        $storage_maps_tls = {}
      }

      pacemaker::resource::bundle { 'galera-bundle':
        image             => $mysql_docker_image,
        replicas          => $galera_nodes_count,
        masters           => $galera_nodes_count,
        location_rule     => {
          resource_discovery => 'exclusive',
          score              => 0,
          expression         => ['galera-role eq true'],
        },
        container_options => 'network=host',
        options           => '--user=root --log-driver=journald -e KOLLA_CONFIG_STRATEGY=COPY_ALWAYS',
        run_command       => '/bin/bash /usr/local/bin/kolla_start',
        network           => "control-port=${control_port}",
        storage_maps      => merge($storage_maps, $storage_maps_tls),
      }

      pacemaker::resource::ocf { 'galera':
        ocf_agent_name  => 'heartbeat:galera',
        master_params   => '',
        meta_params     => "master-max=${galera_nodes_count} ordered=true",
        op_params       => 'promote timeout=300s on-fail=block',
        resource_params => "additional_parameters='--open-files-limit=16384' enable_creation=true wsrep_cluster_address='gcomm://${galera_nodes}' cluster_host_map='${cluster_host_map_string}'",
        tries           => $pcs_tries,
        location_rule   => {
          resource_discovery => 'exclusive',
          score              => 0,
          expression         => ['galera-role eq true'],
        },
        bundle          => 'galera-bundle',
        require         => [Class['::mysql::server'],
                            Pacemaker::Resource::Bundle['galera-bundle']],
        before          => Exec['galera-ready'],
      }

      exec { 'galera-ready' :
        command     => '/usr/bin/clustercheck >/dev/null',
        timeout     => 30,
        tries       => 180,
        try_sleep   => 10,
        environment => ['AVAILABLE_WHEN_READONLY=0'],
        tag         => 'galera_ready'
      }

      # We create databases and users for services at step 2 as well. This ensures
      # Galera is up and ready before those get created
      File['/root/.my.cnf'] -> Mysql_database<||>
      File['/root/.my.cnf'] -> Mysql_user<||>
      File['/etc/sysconfig/clustercheck'] -> Mysql_database<||>
      File['/etc/sysconfig/clustercheck'] -> Mysql_user<||>
      Exec['galera-ready'] -> Mysql_database<||>
      Exec['galera-ready'] -> Mysql_user<||>
    }
  }
}
