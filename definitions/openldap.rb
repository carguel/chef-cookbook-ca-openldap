#
# Cookbook Name:: ca_openldap
# Definition File:: openldap
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

# Generate LDIF schemas related to the schema definitions included in a directory.
define :ldif_additional_schemas do
  ldif_dir = params[:ldif_dir]
  schema_dir = params[:schema_dir]
  import_file = "#{ldif_dir}/import_schemas.conf"

  # Temporary directory
  directory ldif_dir do
    recursive true
    action :create
    notifies :delete, "directory[#{ldif_dir}]" #shall be deleted at the end
  end

  # Build the schema import LDIF file
  ruby_block "schema_import_ldif" do
    block do
      File.open(import_file, "w") do |f|
        node['ca_openldap']['additional_schemas'].each do |schema|
          f.puts "include #{schema_dir}/#{schema}.schema"
        end
      end
    end

    action :create
  end

  # Convert the schemas to LDIF
  execute "ldif_additional_schemas" do
    command "slaptest -f #{import_file} -F #{ldif_dir}"
    action :run
  end
end


# Add a schema defined as LDIF (previously processed by :ldif_additional_schemas) into the local LDAP instance.
define :ldap_additional_schema do
  ldif_dir = params[:ldif_dir]
  schema = params[:schema]

  ldap_config = Chef::Recipe::LDAPConfigUtils.new


  # first update the LDIF schema according to http://www.zytrax.com/books/ldap/ch6/slapd-config.html#use-schemas
  ruby_block "updated_ldif_schema_#{schema}" do
    block do
      ldif = ldap_config.schema_path(ldif_dir, schema)

      f = Chef::Util::FileEdit.new(ldif)
      f.search_file_replace_line(/dn: cn=\{\d+\}/, 
                                 "dn: cn=#{schema},cn=schema,cn=config")
      f.search_file_replace(/cn: \{\d+\}/, "cn: ")
      f.search_file_delete_line(/^(?:structuralObjectClass|entryUUID|creatorsName|createTimestamp|entryCSN|modifiersName|modifyTimestamp):/)
      f.write_file
    end
    action :create
  end

  # add the updated LDIF into the local LDAP instance
  load_ldap_schema do
    schema_name schema
    schema_path ldap_config.schema_path(ldif_dir, schema)
  end
end

# Load some LDAP schema (which name and path are provided as entry parameters) to LDAP database
define :load_ldap_schema do
  schema_name = params[:schema_name]
  schema_path = params[:schema_path]

  ruby_block "load_schema_#{schema_name}" do
    block do
      system "ldapadd -Y EXTERNAL -H ldapi:/// -D cn=admin,cn=config < #{schema_path}"
    end
    action :create
    not_if do
      lcu = Chef::Recipe::LDAPConfigUtils.new
      lcu.contains?(base: "cn=schema,cn=config", filter: "'(cn=*#{schema_name})'")
    end
  end
end

# This definition allows to add a module in the On Line Configuration.
# :name: name of the module, for example "ppolicy"
define :openldap_module do
  name = params[:name]

  # Temporary path
  tmp_module_list = "/tmp/cn=module.ldif"
  tmp_module_add = "/tmp/#{name}_module.ldif"

  # Helper for checking LDAP Online Configuration
  ldap_config = ::Chef::Recipe::LDAPConfigUtils.new

  # Temporary ressources
  file tmp_module_list do
    action :nothing
  end

  file tmp_module_add do
    action :nothing
  end

  # Add the module list entry
  execute "module_list" do
    command "ldapadd -Y EXTERNAL -H ldapi:/// -D cn=admin,cn=config < #{tmp_module_list}"
    action :nothing
  end

  # Add the module into the module list
  execute "#{name}_module" do
    command "ldapmodify -Y EXTERNAL -H ldapi:/// -D cn=admin,cn=config < #{tmp_module_add}"
    action :nothing
  end

  # Create the LDIF for adding the module list
  cookbook_file tmp_module_list do
    source "modules/module.ldif"
    mode 0644
    owner "root"
    group "root"
    not_if {ldap_config.contains?(base: "cn=module{0},cn=config")}
    notifies :run, "execute[module_list]", :immediately
    notifies :delete, "file[#{tmp_module_list}]"
  end

  # Create the LDIF for adding the module into the module list
  template tmp_module_add do
    action :create
    backup false
    source "modules/add_module.ldif"
    variables name: name
    notifies :run, "execute[#{name}_module]", :immediately
    notifies :delete, "file[#{tmp_module_add}]"
    not_if {ldap_config.contains?(base: "cn=module{0},cn=config", filter: "olcModuleLoad=#{name}.la")}
  end
end

# Create a link under node['ca_openldap']['tls']['cert_file'] which points to the server certificate under
# "/etc/pki/tls/certs/#{node['fqdn']}.pem".
#
# This is only a wrapper over the link resource for semantic purpose.
# This definition does not depend on any attribute.
define :server_certificate_link do
  link node['ca_openldap']['tls']['cert_file'] do
    to "/etc/pki/tls/certs/#{node['fqdn']}.pem"
  end
end

# Create a link under node['ca_openldap']['tls']['cacert_path'] which points to the CA Certificate under 
# "/etc/pki/tls/certs/#{node['hostname']}-bundle.crt".
#
# The name of the created link is the X.509 hash with the extension ".0" in order to comply with what it is
# expected by OpenLDAP.
# This definition does not depend on any attribute.
define :ca_certificate_link do

  directory node['ca_openldap']['tls']['cacert_path'] do
    mode 0755
    owner "root"
    group "root"
  end

  ruby_block "ca_certificate_link" do
    block do
      ca_cert = "/etc/pki/tls/certs/#{node['hostname']}-bundle.crt"
      link_name = File.join(node['ca_openldap']['tls']['cacert_path'], `openssl x509 -hash -noout -in #{ca_cert}`.chomp + ".0")
      FileUtils.ln_s(ca_cert, link_name, force: true)
    end
    action :create
  end
end

# Create a link under node['ca_openldap']['tls']['key_file'] which points to the private key file under
# "/etc/pki/private/#{node['fqdn']}.key.
#
# This definition does not depend on any attribute.
define :private_key_link do

  # We create a hardlink in order to be able 
  # to set a different owner, group and mode
  link node['ca_openldap']['tls']['key_file'] do
    to "/etc/pki/tls/private/#{node['fqdn']}.key"
    link_type :hard
  end

  file node['ca_openldap']['tls']['key_file'] do
    owner "root"
    group "ldap"
    mode  0640
  end
end
