#
# Cookbook Name:: ca_openldap
# Recipe File:: server
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

include_recipe 'ca_openldap::default'

class Chef::Recipe
  include CAOpenldap
end

include_recipe "ca_openldap::client"

# Install needed packages
package "openldap-servers" do
  action :upgrade
end

# Enable slapd service and stop it in order to complete its configuration
service "slapd" do
  action [:enable, :stop]
end

directory node.ca_openldap.db_dir do
  user "ldap"
  group "ldap"
  mode 0700
  recursive true
end

general_configuration_options = {}.merge node['ca_openldap']['general_configuration_options']

# Set options to manage TLS certificate and key path 
if node.ca_openldap.tls.enable.to_sym != :no
  general_configuration_options['olcTLSCACertificatePath'] = node.ca_openldap.tls.cacert_path
  general_configuration_options['olcTLSCertificateFile'] = node.ca_openldap.tls.cert_file
  general_configuration_options['olcTLSCertificateKeyFile'] = node.ca_openldap.tls.key_file
end

# Update general configuration options.
ca_openldap_general_configuration "global_options" do
  options general_configuration_options
  not_if { general_configuration_options.empty? }
end

# TLS connection configuration
(use_ldap, use_ldaps) = use_ldap_or_ldaps?(node.ca_openldap.tls.enable.to_sym)
ldap_port = node.ca_openldap.default_ports.ldap
ldaps_port = node.ca_openldap.default_ports.ldaps

urls = []
urls << "ldap://*:#{ldap_port}" if use_ldap == "yes"
urls << "ldaps://*:#{ldaps_port}" if use_ldaps == "yes"

ruby_block "tls_connection_configuration" do
  block do
    f = Chef::Util::FileEdit.new("/etc/sysconfig/ldap")
    f.search_file_replace_line(/SLAPD_LDAP=/, "SLAPD_LDAP=no")
    f.search_file_replace_line(/SLAPD_LDAPS=/, "SLAPD_LDAPS=no")
    f.search_file_replace_line(/SLAPD_LDAPI=/, "SLAPD_LDAPI=yes")
    f.search_file_replace_line(/SLAPD_URLS=/, "SLAPD_URLS=\"#{urls.join ""}\"")
    f.write_file
  end
end

if (use_ldaps == "yes") && node.ca_openldap.use_existing_certs_and_key
  server_certificate_link do
    action :create
  end

  private_key_link do
    action :create
  end
  
  ca_certificate_link do
    action :create
  end
end

# Configure the base DN, the root DN and its password
my_root_dn = build_rootdn
ruby_block "bdb_config" do
  block do

    slapd_conf_file = '/etc/openldap/slapd.d/cn=config/olcDatabase={2}bdb.ldif'
    password = LDAPUtils.ssha_password(node.ca_openldap.rootpassword)

    #configure suffix
    f = Chef::Util::FileEdit.new(slapd_conf_file)
    f.search_file_replace_line(/olcDbDirectory:/, "olcDbDirectory: #{node.ca_openldap.db_dir}")
    f.search_file_replace_line(/olcSuffix:/, "olcSuffix: #{node.ca_openldap.basedn}")

    #configure root dn and root password
    f.search_file_replace_line(/olcRootDN:/, "olcRootDN: #{my_root_dn}")
    f.search_file_delete_line(/olcRootPW:/)
    f.insert_line_after_match(/olcRootDN:/, "olcRootPW: #{password}")
    
    #configure log level
    f.search_file_delete_line(/olcLogLevel:/)
    f.insert_line_after_match(/olcRootPW:/, "olcLogLevel: #{node.ca_openldap.ldap_log_level}")
    
    #configure acl
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
