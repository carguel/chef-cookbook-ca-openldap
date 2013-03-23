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

# Configure the base DN, the root DN and its password
ruby_block "set_basedn" do
  block do

    slapd_conf_file = '/etc/openldap/slapd.d/cn=config/olcDatabase={2}bdb.ldif'
    password = LDAPUtils.ssha_password(node.ca_openldap.rootpassword)

    f = Chef::Util::FileEdit.new(slapd_conf_file)
    f.search_file_replace_line(/olcSuffix:/, "olcSuffix: #{node.ca_openldap.basedn}")
    f.search_file_replace_line(/olcRootDN:/, "olcRootDN: #{node.ca_openldap.rootdn}")
    f.search_file_delete_line(/olcRootPW:/)
    f.insert_line_after_match(/olcRootDN:/, "olcRootPW: #{password}")
    f.search_file_delete_line(/olcLogLevel:/)
    f.insert_line_after_match(/olcRootPW:/, "olcLogLevel: #{node.ca_openldap.ldap_log_level}")
    f.search_file_delete_line(/olcAccess:/)

    index = 0
    acls = node.ca_openldap.acls.inject("") do |acum, acl|
      acum << "olcAccess: {#{index}}#{acl}\n"
      index+= 1
      acum
    end
    puts acls
    f.insert_line_after_match(/olcLogLevel:/, acls)

    f.write_file
  end
  action :create
  notifies :start, "service[slapd]", :immediately
end
