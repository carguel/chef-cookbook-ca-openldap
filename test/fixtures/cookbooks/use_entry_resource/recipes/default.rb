ca_openldap_entry "uid=new_entry,ou=users" do
  attributes objectClass: ["top", "posixAccount", "inetOrgPerson"],
             uidNumber: "22001",
             cn: "new_entry 2",
             gidNumber: "22001",
             sn: "new entry user",
             userPassword: "pa$$word",
             homeDirectory: "/home/new_entry"
end
