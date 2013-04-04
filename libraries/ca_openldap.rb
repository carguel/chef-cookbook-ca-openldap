module Chef::Recipe::CAOpenldap

  
  def parse_populate_data_bag_item

    config = data_bag_item('ca_openldap', 'populate')
    base = config['base']

    config['branches'].each do |branch|
      branch_dn = Chef::Recipe::LDAPUtils.build_dn(branch['name'], base)
      default_classes = branch['default_classes']
      branch['entries'].each do |entry|
        dn = Chef::Recipe::LDAPUtils.build_dn(entry['dn'], branch_dn)
        attrs = entry.merge(Chef::Recipe::LDAPUtils.first_item(dn))
        attrs.delete('dn')
        attrs["objectClass"] = default_classes

        yield(dn, attrs)

      end
    end
  end

  # Build the rootdn.
  # The rootdn attribute provides the rootdn relatively to the basedn.
  # This helper method concatenates the rootdn attribute and the basedn
  # to build the absolute rootdn.
  # @return [String] the absolute rootdn.
  def build_rootdn 
    [node.ca_openldap.rootdn, node.ca_openldap.basedn].join(',')
  end
end
