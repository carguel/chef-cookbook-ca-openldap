
schema_dir = "/etc/openldap/schema"
ldif_dir = "/tmp/ldif_schemas"

# Copy the schemas from the cookbook file distribution
remote_directory schema_dir do
  cookbook node.ca_openldap.schema_cookbook
  source "schemas"
  action :create
  files_mode 00644
  files_owner 'root'
  files_group 'root'
end

#convert schemas as LDIF
ldif_schemas  do
  ldif_dir ldif_dir
  schema_dir schema_dir
end

#import schemas into LDAP
node.ca_openldap.additional_schemas.each do |schema_name|
  ldap_schemas do
    ldif_dir ldif_dir
    schema schema_name
  end
end
