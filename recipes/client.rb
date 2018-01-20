#
# Cookbook Name:: ca_openldap
# Recipe File:: client
#
# Copyright 2013, Christophe Arguel <christophe.arguel@free.fr>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef::Recipe
  include CAOpenldap
end

package "openldap-clients" do
  action :upgrade
end

ldap_conf = case node['platform_family']
when "rhel"
  "/etc/openldap/ldap.conf"
else
  Chef::Application.fatal!("Platform not supported")
end

template ldap_conf do
  user "root"
  group "root"
  source "ldap.conf.erb"
end

ca_certificate_link do
  action :create
end
