chef_gem 'net-ldap'

require 'net/ldap'

ruby_block "Create_DIT" do
  block do 

    # Get the DIT definition.
    # First check if a 'dit' data bag item exists, and return the 'dit' hash included in this data bag item.
    # Otherwise return the node attribute cg.openldap.dit data bag item.
    # Otherwise return the node attribute cg.openldap.dit.  
    def get_dit_definition
      if data_bag('ca_openldap') && data_bag('ca_openldap').include?('dit')
        Chef::Log.info 'load dit data bag'
        data_bag_item('ca_openldap', 'dit')["dit"]
      else
        node.ca_openldap.dit
      end
    end

    lu = LDAPUtils.new(node.ca_openldap.ldap_server, node.ca_openldap.ldap_port, node.ca_openldap.rootdn, node.ca_openldap.rootpassword)

    # The parse method is defined dynamically in order to have access to the lu variable.
    # This is a recursive method.
    self.define_singleton_method(:parse) do |branch, context= nil|
      branch.each do |dn, entry|
        dn += ",#{context}" if context
        attrs = entry["attrs"].merge(LDAPUtils.first_item(dn))
        lu.add_entry dn, attrs
        parse(entry["children"], dn) if entry.has_key? "children"
      end
    end

    dit = get_dit_definition
    parse dit
  end
end
