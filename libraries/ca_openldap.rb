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

  # Determine if slapd must use LDAP and/or LDAPS protocol depending on the tls_mode.
  # @param [String] tls_mode the TLS mode, the following values are supported
  #   * :no - TLS connections are not supported, only clear connections are supported
  #   * :yes- TLS and clear connections are supported
  #   * :exclusive - only TLS connections are supported
  # @return [Array<String>] an array of two elements, each element equals either "yes" or "no", 
  # the first element indicates if plain connections (LDAP) are supported, the second element 
  # indicates if TLS connections (LDAPS) are supported.
  # @raise [Exception] tls_mode value is not supported.
  def use_ldap_or_ldaps?(tls_mode)
    case tls_mode
    when :no
      ["yes", "no"]
    when :yes
      ["yes", "yes"]
    when :exclusive
      ["no", "yes"]
    else
      raise "unsupported value #{tls_mode} for TLS configuration"
    end
  end
end
