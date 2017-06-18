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

include_recipe 'ca_openldap::_install_gems'

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

# Configure permissions on main directories
directory node['ca_openldap']['db_dir'] do
  user "ldap"
  group "ldap"
  mode 0700
  recursive true
end
directory node['ca_openldap']['config_dir'] do
  user "ldap"
  group "root"
  mode 0700
  recursive true
end

general_configuration_options = {}.merge node['ca_openldap']['general_configuration_options']

# Set options to manage TLS certificate and key path 
if node['ca_openldap']['tls']['enable'].to_sym != :no
  general_configuration_options['olcTLSCACertificatePath'] = node['ca_openldap']['tls']['cacert_path']
  general_configuration_options['olcTLSCertificateFile'] = node['ca_openldap']['tls']['cert_file']
  general_configuration_options['olcTLSCertificateKeyFile'] = node['ca_openldap']['tls']['key_file']
end

# Configure the log level as a general configuration option
general_configuration_options['olcLogLevel'] = node['ca_openldap']['ldap_log_level']

# Update general configuration options.
ca_openldap_general_configuration "global_options" do
  options general_configuration_options
  not_if { general_configuration_options.empty? }
end

# TLS connection configuration
(_, use_ldaps) = use_ldap_or_ldaps?(node.ca_openldap.tls.enable.to_sym)

ruby_block "tls_connection_configuration" do
  extend Chef::Recipe::CAOpenldap
  block do
    f = Chef::Util::FileEdit.new(node['ca_openldap']['slapd_sysconfig_file'])
    f.search_file_replace_line(/SLAPD_LDAP=/, "SLAPD_LDAP=no")
    f.search_file_replace_line(/SLAPD_LDAPS=/, "SLAPD_LDAPS=no")
    f.search_file_replace_line(/SLAPD_LDAPI=/, "SLAPD_LDAPI=no")
    f.search_file_replace_line(/SLAPD_URLS=/, "SLAPD_URLS=\"#{ slapd_listen_urls }\"")
    f.write_file
  end
end

if (use_ldaps == "yes") && node['ca_openldap']['use_existing_certs_and_key']
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

# Configure the database backend (defining among others the base DN, the root DN and its password)
my_root_dn = build_rootdn
ruby_block "db_backend_config" do
  block do

    # rename db backend conf file according to the chosen backend
    db_conf_file = Dir["#{node['ca_openldap']['config_dir']}/cn=config/olcDatabase=\{*\}{hdb,bdb,mdb}.ldif"].first
    db_conf_file_init_name_data = File.basename(db_conf_file).match(/{(?<db_index>[[:digit:]]+)}(?<db_backend>[[:alpha:]]+)\.ldif/)
    db_index = db_conf_file_init_name_data['db_index']
    init_db_backend = db_conf_file_init_name_data['db_backend']
    target_db_backend = node['ca_openldap']['db_backend']
    if ! target_db_backend.eql? init_db_backend
      db_conf_file_old = db_conf_file
      db_conf_file = "#{File.dirname(db_conf_file)}/olcDatabase={#{db_index}}#{target_db_backend}.ldif"
      File.rename(db_conf_file_old, db_conf_file)
    end

    # configure this file's permissions
    FileUtils.chown('root', 'ldap', db_conf_file)
    FileUtils.chmod(0640, db_conf_file)

    # open the file
    f = Chef::Util::FileEdit.new(db_conf_file)
    
    # if the db backend chosen isn't the default one, modify the file accordingly
    if ! target_db_backend.eql? init_db_backend
      #configure database
      f.search_file_replace_line(/dn:/, "dn: olcDatabase={#{db_index}}#{target_db_backend}")
      f.search_file_replace_line(/olcDatabase:/, "olcDatabase: {#{db_index}}#{target_db_backend}")

      #configure database class
      upFirstLetter = ->(string) { string.slice(0,1).capitalize + string.slice(1..-1) }
      old_db_object_class = 'olc' + upFirstLetter.call(init_db_backend) + 'Config'
      new_db_object_class = 'olc' + upFirstLetter.call(target_db_backend) + 'Config'
      f.search_file_replace_line(/objectClass:[[:blank:]]*#{old_db_object_class}/, "objectClass: #{new_db_object_class}")
      f.search_file_replace_line(/structuralObjectClass:/, "structuralObjectClass: #{new_db_object_class}")
    end

    #configure database storage irectory
    f.search_file_replace_line(/olcDbDirectory:/, "olcDbDirectory: #{node['ca_openldap']['db_dir']}")
    
    #configure suffix
    f.search_file_replace_line(/olcSuffix:/, "olcSuffix: #{node['ca_openldap']['basedn']}")

    #configure root dn and root password
    f.search_file_replace_line(/olcRootDN:/, "olcRootDN: #{my_root_dn}")
    f.search_file_delete_line(/olcRootPW:/)
    password = LDAPUtils.ssha_password(node['ca_openldap']['rootpassword'])
    f.insert_line_after_match(/olcRootDN:/, "olcRootPW: #{password}")
    
    #configure acl
    f.search_file_delete_line(/olcAccess:/)
    index = 0
    acls = node['ca_openldap']['acls'].inject("") do |acum, acl|
      acum << "olcAccess: {#{index}}#{acl}\n"
      index+= 1
      acum
    end
    f.insert_line_after_match(/olcRootPW:/, acls)

    f.write_file
  end
  action :create
  notifies :start, "service[slapd]", :immediately
end

