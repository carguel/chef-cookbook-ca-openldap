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

# Configure ACL in the slapd DB configuration file.
#

tmp_slapd_config =  File.join(Chef::Config['file_cache_path'], 'slapd_db_config.ldif')

# Copy actual slapd DB config file to a temporary file
file tmp_slapd_config do
  extend CAOpenldap
  content lazy { File.read slapd_db_config_file }
end

# Update the content of the temporary file
# with expected ACL.
ruby_block "acl_config" do
  block do
    extend CAOpenldap

    slapd_conf_file = tmp_slapd_config

    #configure acl
    f = Chef::Util::FileEdit.new(slapd_conf_file)
    f.search_file_delete_line(/olcAccess:/)
    index = 0
    acls = node['ca_openldap']['acls'].inject("") do |acum, acl|
      acum << "olcAccess: {#{index}}#{acl}\n"
      index+= 1
      acum
    end
    f.insert_line_after_match(/olcRootPW:/, acls)

    f.write_file

    # Remove FileEdit backup file.
    File.delete("#{ tmp_slapd_config }.old")

  end
  action :create
  notifies :delete, "file[#{ tmp_slapd_config }]"
end

# Copy updated content to the actual slapd DB config file.
# NB: path is unknown at compile time during the first run.
file "slapd_db_config_with_updated_acls" do
  extend CAOpenldap
  path lazy { slapd_db_config_file }
  content lazy { File.read tmp_slapd_config }
  notifies :restart, "service[slapd]"
end
