#
# Cookbook Name:: ca_openldap
# Library File:: ldap_utils
#
# Copyright 2013, Christophe Arguel <christophe.arguel@free.fr>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Chef::Recipe::LDAPHelpers

  # Check that the :base key is presents in the options hash
  def check_base(opts)
    base = opts[:base] or raise ":base option shall be provided"
  end

  # Extract the index of an OLC entry.
  def extract_index entry
    m = entry.match /\{(\d+)\}/
    m[1].to_i if m
  end
end

class Chef::Recipe::LDAPUtils
  include Chef::Recipe::LDAPHelpers

  def initialize(server, port, dn, password, tls_enable)
    args = {host: server, port: port.to_i, auth: {method: :simple, username: dn, password: password}}

    args.merge!(encryption: {method: :simple_tls}) if tls_enable
    @ldap = Net::LDAP.new(args)
  end

  # Add an entry in the directory
  # @param [String] dn the dn of the entry to add
  # @param [Hash] attrs the attributes of the entry
  def add_entry(dn, attrs)
    if exists?(dn)
      Chef::Log.info("ldap entry dn=#{dn} already exists => not added")
    else
      Chef::Log.info("add ldap entry dn=#{dn}, attributes=#{attrs}")
      @ldap.add(dn: dn, attributes: attrs) or raise "Add LDAP entry failed, cause: #{@ldap.get_operation_result}"
    end
  end

  # Add an entry in the directory or update an existing one
  # @param [String] dn the dn of the entry to add
  # @param [Hash] attrs the attributes of the entry
  def add_or_update_entry(dn, attrs, *attributes_to_ignore)
    entries = @ldap.search(base: dn, scope: Net::LDAP::SearchScope_BaseObject, return_result: true)
    raise "#{dn} does not match a single entry" if entries && entries.size > 1

    if entries.nil?
      add_entry(dn, attrs)
    else
      entry = entries.first
      ops = attrs.inject(Array.new) do |accum, (key, value)|
        if Array(entry[key]) != Array(value) && ! ignored_attribute?(key, attributes_to_ignore)
          accum << [:replace, key, value] 
        end
        accum
      end


      if not ops.empty?
        Chef::Log.info("update ldap entry dn=#{dn}, attributes=#{attrs}")
        @ldap.modify(dn: dn, operations: ops) or raise "Update LDAP entry failed, cause: #{@ldap.get_operation_result}"
      end
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
    SSHA.hash_password(clear_password).gsub(/^.+\*/, "")
  end

  private

  # Test if an attribute must be ignored.
  #
  # The equality is based on the lowercase stringified form og the attribute and the
  # elements of the list.
  #
  # @param [#to_s] attribute Attribute name.
  # @param [Array<#to_s>] attributes_to_ignore List of attributes to ignore.
  # @return [true|false] true if the attribute is includes in the list of attributes to ignore.
  def ignored_attribute?(attribute, attributes_to_ignore)
    attributes_to_ignore.map(&:to_s).include?(attribute.to_s)
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

  # Get the absolute path of an LDIF schema file given the root of the LDIF config
  def schema_path(ldif_config_dir, schema_name)
    path = Dir["#{ldif_config_dir}/cn=config/cn=schema/*#{schema_name}.ldif"].first
  end
end
