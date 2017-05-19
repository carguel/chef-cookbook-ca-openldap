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

# Enable slapd service and stop it in order to complete its configuration
service "slapd" do
  action [:enable, :stop]
end

# Configure the base DN, the root DN and its password
my_root_dn = build_rootdn
ruby_block "acl_config" do
  block do
    slapd_conf_file = '/etc/openldap/slapd.d/cn=config/olcDatabase={2}bdb.ldif'
    #configure acl
    f = Chef::Util::FileEdit.new(slapd_conf_file)
    f.search_file_delete_line(/olcAccess:/)
    index = 0
    acls = node.ca_openldap.acls.inject("") do |acum, acl|
      acum << "olcAccess: {#{index}}#{acl}\n"
      index+= 1
      acum
    end
    f.insert_line_after_match(/olcLogLevel:/, acls)

    f.write_file
  end
  action :create
  notifies :start, "service[slapd]", :immediately
end