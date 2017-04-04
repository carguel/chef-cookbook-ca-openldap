#
# Cookbook Name:: ca_openldap
# Recipe File:: ppolicy
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

include_recipe 'ca_openldap::_install_gems'

class Chef::Recipe
    include CAOpenldap
end

#configure module
openldap_module "ppolicy" do
  action :run
end

my_root_dn = build_rootdn()
ldap_config = Chef::Recipe::LDAPConfigUtils.new
ldap = Chef::Recipe::LDAPUtils.new(node['ca_openldap']['ldap_server'], node['ca_openldap']['ldap_port'].to_i,
                                   my_root_dn, node['ca_openldap']['rootpassword'], tls_enable?(node['ca_openldap']['tls']['enable']) )


tmp_ppolicy_overlay_ldif = "/tmp/ppolicy_overlay.ldif"

# temporary LDIF files
file "#{tmp_ppolicy_overlay_ldif}" do
  action :nothing
end

# Create the ppolicy overlay definition LDIF
template "#{tmp_ppolicy_overlay_ldif}" do
  source "overlay/ppolicy_overlay.ldif"
  backup false
  mode 0600
  owner "root"
  group "root"
  notifies :run, "execute[ppolicy_overlay]", :immediately
  notifies :delete, "file[#{tmp_ppolicy_overlay_ldif}]"
  not_if {ldap_config.contains?(base: "cn=config", filter: "olcOverlay=ppolicy")}
end

# Add the overlay definition into the On Line Configuration
execute "ppolicy_overlay" do
  command "ldapadd -Y EXTERNAL -H ldapi:/// -D cn=admin,cn=config < #{tmp_ppolicy_overlay_ldif}"
  action :nothing
end

# Using the On Line Configuration, add:
# - the ppolicy default config,
# - any supplementary ppolicy specified within node['ca_openldap']['extra_ppolicies']
[{
  dn: node['ca_openldap']['ppolicy_default_config_dn'],
  sn: "PPolicy default config",
  attrs: node['ca_openldap']['ppolicy_default_config']
}]
.concat(node['ca_openldap']['ppolicy']['extra_ppolicies'])
.each do |ppolicy|
  ruby_block "ppolicy_config_#{ppolicy[:dn]}" do
    block do
      attrs = {
        objectClass: ["pwdPolicy", "person", "top", "pwdPolicyChecker"],
        sn: ppolicy[:sn]
      }.merge(ppolicy[:attrs])

      ppolicy_config_full_dn = [ppolicy[:dn], node['ca_openldap']['basedn']].join(',')
      ldap.add_or_update_entry(ppolicy_config_full_dn, attrs)
    end
    action :create
  end
end
