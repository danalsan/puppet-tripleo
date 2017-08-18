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
# == Class: tripleo::profile::base::neutron::ovn_metadata
#
# Networking-ovn Metadata Agent profile for tripleo
#
# === Parameters
#
# [*step*]
#   (Optional) The current step in deployment. See tripleo-heat-templates
#   for more details.
#   Defaults to hiera('step')
#
class tripleo::profile::base::neutron::ovn_metadata (
  $step = Integer(hiera('step')),
) {
  if $step >= 4 {
    include ::tripleo::profile::base::neutron
    include ::tripleo::profile::base::ovn_params
    include ::neutron::agents::ovn_metadata

    class { 'neutron::agents::ovn_metadata':
      ovn_nb_connection => $tripleo::profile::base::ovn_params::nb_connection,
      ovn_sb_connection => $tripleo::profile::base::ovn_params::sb_connection,
    }
    Service<| title == 'controller' |> -> Service<| title == 'ovn-metadata' |>
  }
}
