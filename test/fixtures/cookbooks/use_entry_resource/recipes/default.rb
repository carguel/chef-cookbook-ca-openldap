# Create an entry giving a relative DN
ca_openldap_entry "uid=new_entry,ou=users" do
  attributes objectClass: ["top", "posixAccount", "inetOrgPerson"],
             uidNumber: "22001",
             cn: "new_entry",
             gidNumber: "22001",
             sn: "new entry user",
             userPassword: "pa$$word",
             homeDirectory: "/home/new_entry"
end

# Create an entry giving a fully qualified DN
ca_openldap_entry "uid=new_entry_2,ou=users,dc=example,dc=com" do
  attributes objectClass: ["top", "posixAccount", "inetOrgPerson"],
             uidNumber: "22002",
             cn: "new_entry_2",
             gidNumber: "22001",
             sn: "new entry user 2",
             userPassword: "pa$$word",
             homeDirectory: "/home/new_entry_2"
end
