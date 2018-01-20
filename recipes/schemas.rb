#
# Cookbook Name:: ca_openldap
# Recipe File:: schemas
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

schema_dir = node['ca_openldap']['schema_dir']
ldif_dir = "/tmp/ldif_schemas"

# Load all configured core LDAP schemas to LDAP database
# (N.B. by default, only the core schema is loaded)
node['ca_openldap']['default_schemas'].each do |schema_name|
  load_ldap_schema do
    schema_name schema_name
    schema_path "#{schema_dir}/#{schema_name}.ldif"
  end
end

# Copy the additional schemas from the cookbook file distribution
remote_directory schema_dir do
  cookbook node['ca_openldap']['schema_cookbook']
  source "schemas"
  action :create
  files_mode 00644
  files_owner 'root'
  files_group 'root'
  not_if { node['ca_openldap']['additional_schemas'].empty? }
end

#convert additional schemas as LDIF
ldif_additional_schemas do
  ldif_dir ldif_dir
  schema_dir schema_dir
  not_if { node['ca_openldap']['additional_schemas'].empty? }
end

#import additional schemas into LDAP
node['ca_openldap']['additional_schemas'].each do |schema_name|
  ldap_additional_schema "ldap_schema_#{schema_name}" do
    ldif_dir ldif_dir
    schema schema_name
  end
end
