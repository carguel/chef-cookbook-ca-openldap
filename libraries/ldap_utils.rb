require 'active_ldap'
require 'net/ldap'

module Chef::Recipe::LDAPHelpers
  def check_base(opts)
    base = opts[:base] or raise ":base option shall be provided"
  end
end

class Chef::Recipe::LDAPUtils
  include Chef::Recipe::LDAPHelpers

  def initialize(server, port, dn, password)
    @ldap = Net::LDAP.new(host: server, port: port, auth: {method: :simple, username: dn, password: password} )
  end

  # Add an entry in the directory
  # @param [String] dn the dn of the entry to add
  # @param [Hash] attrs the attributes of the entry
  def add_entry(dn, attrs)
    if exists?(dn)
      Chef::Log.info("dn=#{dn} already exists")
    else
      Chef::Log.info("add ldap entry dn=#{dn}, attributes=#{attrs}")
      @ldap.add(dn: dn, attributes: attrs) or raise "Add LDAP entry failed, cause: #{@ldap.get_operation_result}"
    end
  end

  # Test if the given entry exists
  # @param [String] dn dn of the entry
  def exists?(dn)
    @ldap.search(base: dn, scope: Net::LDAP::SearchScope_BaseObject, return_result: false)
  end

  # Test if the local directory contains entries under the provided base and matching a filter if given.
  # The connection to the LDAP is made with the EXTERNAL SASL scheme.
  # @param [Hash] opts options
  # @option opts [String] :base the basedn to search from (mandatory)
  # @option opts [String] :filter the filter to match
  # @return [TrueClass|FalseClass] true if entries are found, false otherwise
  def contains?(opts = {})
    base = check_base opts
    filter = if opts[:filter]
               Net::LDAP::Filter.construct opts[:filter]
             else
                Net::LDAP::Filter.new
             end
    @ldap.search(base: base, filter: filter, return_result: false)
  end

  # Extract the first item of the given dn
  # @param [String] dn the dn to consider
  # @return [Hash] the key/value pair related to the first item of the dn
  def self.first_item(dn) 
    m = dn.match(/^([^=]+)=([^,]+)/)
    {m[1] => m[2]}
  end

  def self.build_dn(*items)
    items.join ','
  end

  # Hash the given password according to SSHA schema, the salt is randomly generated.
  # @param [String] password the password to hash
  # @return [String] the hashed password
  def self.ssha_password(clear_password)
    ActiveLdap::UserPassword.ssha clear_password
  end
end

class Chef::Recipe::LDAPConfigUtils
  include Chef::Recipe::LDAPHelpers

  def contains?(opts = {})
    base = check_base opts
    filter = if opts.has_key? :filter
               opts[:filter]
             else
               ""
             end
    system("ldapsearch -Y EXTERNAL -H ldapi:// -b #{base} #{filter} | grep -q 'numEntries:'")
  end
end
