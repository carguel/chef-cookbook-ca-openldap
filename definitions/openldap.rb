# Generate LDIF schemas related to the schema definitions included in a directory.
define :ldif_schemas do
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
        node.ca_openldap.additional_schemas.each do |schema|
          f.puts "include #{schema_dir}/#{schema}.schema"
        end
      end
    end

    action :create
  end

  # Convert the schemas to LDIF
  execute "ldif_schemas" do
    command "slaptest -f #{import_file} -F #{ldif_dir}"
    action :run
  end
end


# Add a schema defined as LDIF into the local LDAP instance.
define :ldap_schema do
  ldif_dir = params[:ldif_dir]
  schema = params[:schema]

  ldap_config = Chef::Recipe::LDAPConfigUtils.new


  # first update the LDIF schema according to http://www.zytrax.com/books/ldap/ch6/slapd-config.html#use-schemas
  ruby_block "updated_ldif_schema" do
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
  ruby_block "imported_schema" do
    block do
      ldif = ldap_config.schema_path(ldif_dir, schema)
      system "ldapadd -Y EXTERNAL -H ldapi:/// -D cn=admin,cn=config < #{ldif}"
    end
    action :create
    not_if do
      lcu = Chef::Recipe::LDAPConfigUtils.new
      lcu.contains?(base: "cn=schema,cn=config", filter: "'(cn=*#{schema})'")
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
