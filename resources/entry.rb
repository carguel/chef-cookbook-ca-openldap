# DN of the entrey to manage.
property :entry_dn, String, name_property: true

# Attributes to set.
property :attributes, Hash, default: {}, sensitive: true

# This module is needed so that 
# exported methods can be invoked both from the action and
# the load_current_value method.
module CAOpenldapEntryHelper

  include ::Chef::Recipe::CAOpenldap

  # Memoize the LDAP client.
  def ldap_client
    @ldap_client ||= 
      begin
        rootdn = build_rootdn
        tls_enable = tls_enable?(node['ca_openldap']['tls']['enable'])
        Chef::Recipe::LDAPUtils.new(node['ca_openldap']['ldap_server'], 
                                    node['ca_openldap']['ldap_port'], 
                                    rootdn, 
                                    node['ca_openldap']['rootpassword'], 
                                    tls_enable
                                   )
      end
  end

  # Fully qualify the entry (append the base DN if needed).
  def fq_entry_dn
    if entry_dn.end_with? basedn
      entry_dn
    else
      "#{entry_dn},#{basedn}" 
    end
  end

  # Retrieve base DN from cookbook attributes.
  def basedn
    node['ca_openldap']['basedn']
  end
end

# Share the CAOpenldapEntryHelper module methods to the action.
action_class do
  include CAOpenldapEntryHelper
end

# Read current attributes of the entry from LDAP.
load_current_value do
  extend CAOpenldapEntryHelper

  entry_attributes = ldap_client.retrieve_entry_attributes(fq_entry_dn)

  # Ensure all keys are downcase.
  entry_attributes.each do |key, value|
    attributes[key.downcase] = value
  end
end

# Create or update an entry.
action :create do

  # Ensure all keys of the attributes property are downcase.
  down_case_attributes = {}
  attributes.each do |k, v|
    down_case_attributes[k.downcase] = v
    attributes.delete k
  end

  down_case_attributes.each do |k, v|
    attributes[k] = v
  end

  # assign a variable for latter use in the ruby block resource.
  entry = fq_entry_dn

  converge_if_changed do
    ruby_block "set_attributes_of_entry_with_dn #{entry}" do
      block do
        ldap_client.add_or_update_entry(entry, attributes)
      end
    end
  end
end
