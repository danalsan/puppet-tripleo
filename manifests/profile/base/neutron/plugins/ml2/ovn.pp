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
# == Class: tripleo::profile::base::neutron::plugins::ml2::ovn
#
# OVN Neutron ML2 profile for tripleo
#
# [*ovn_db_host*]
#   The IP-Address where OVN DBs are listening.
#   Defaults to hiera('ovn_dbs_vip')
#
# [*ovn_nb_port*]
#   (Optional) Port number on which northbound database is listening
#   Defaults to hiera('ovn::northbound::port')
#
# [*ovn_sb_port*]
#   (Optional) Port number on which southbound database is listening
#   Defaults to hiera('ovn::southbound::port')
#
# [*step*]
#   (Optional) The current step in deployment. See tripleo-heat-templates
#   for more details.
#   Defaults to hiera('step')
#
class tripleo::profile::base::neutron::plugins::ml2::ovn (
  $ovn_db_host = hiera('ovn_dbs_vip'),
  $ovn_nb_port = hiera('ovn::northbound::port'),
  $ovn_sb_port = hiera('ovn::southbound::port'),
  $step        = Integer(hiera('step'))
) {
  if $step >= 4 {
    class { '::neutron::plugins::ml2::ovn':
      ovn_nb_connection => "tcp:${ovn_db_host}:${ovn_nb_port}",
      ovn_sb_connection => "tcp:${ovn_db_host}:${ovn_sb_port}",
    }
  }
}

