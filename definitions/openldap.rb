# Generate LDIF schemas related to the schema definitions included in a directory.
define :ldif_schemas do
  ldif_dir = params[:ldif_dir]
  schema_dir = params[:schema_dir]
  import_file = "#{ldif_dir}/import_schemas.conf"

  directory ldif_dir do
    recursive true
    action :create
    notifies :delete, "directory[#{ldif_dir}]" #shall be deleted at the end
  end

  ruby_block "build_schema_configuration_file" do
    block do
      File.open(import_file, "w") do |f|
        node.ca_openldap.additional_schemas.each do |schema|
          f.puts "include #{schema_dir}/#{schema}.schema"
        end
      end
    end

    action :create
  end

  # Convert the schemas to LDIF
  execute "convert_schema_to_ldif" do
    command "slaptest -f #{import_file} -F #{ldif_dir}"
    action :run
  end
end

# Add schemas defined as LDIF into the local LDAP instance.
define :ldap_schemas do
  ldif_dir = params[:ldif_dir]
  schema = params[:schema]
  ldif = Dir["#{ldif_dir}/cn=config/cn=schema/*#{schema}.ldif"].first

  # first update the LDIF schema according to http://www.zytrax.com/books/ldap/ch6/slapd-config.html#use-schemas
  ruby_block "update_ldif" do
    block do
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
  execute "import_ldif" do
    command "ldapadd -Y EXTERNAL -H ldapi:/// -D cn=admin,cn=config < #{ldif}"
    action :run
    not_if do
      lcu = Chef::Recipe::LDAPConfigUtils.new
      lcu.contains?(base: "cn=schema,cn=config", filter: "cn=*#{schema}")
    end
  end
end
