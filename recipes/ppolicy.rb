#configure module

openldap_module "ppolicy" do
  action :run
end

ldap_config = Chef::Recipe::LDAPConfigUtils.new
ldap = Chef::Recipe::LDAPUtils.new(node.ca_openldap.ldap_server, node.ca_openldap.ldap_port, node.ca_openldap.rootdn, node.ca_openldap.rootpassword)

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

# Add the ppolicy default config into the On Line Configuration
ruby_block "ppolicy_config" do
  block do
    attrs = {
      objectClass: ["pwdPolicy", "person", "top"],
      sn: "PPolicy default config"
    }.merge(node.ca_openldap.ppolicy_default_config)

    ppolicy_default_config_dn = [node.ca_openldap.ppolicy_default_config_dn, node.ca_openldap.basedn].join(",")
    ldap.add_or_update_entry(ppolicy_default_config_dn, attrs)
  end
  action :create
end
