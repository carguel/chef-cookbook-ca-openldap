#
# Cookbook Name:: ca_openldap
# Library File:: ca_openldap
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

module Chef::Recipe::CAOpenldap

  
  def parse_populate_data_bag_item

    data_bag, item = populate_data_bag_item_name

    config = data_bag_item(data_bag, item)
    base = config['base']

    config['branches'].each do |branch|
      branch_dn = Chef::Recipe::LDAPUtils.build_dn(branch['name'], base)
      default_classes = branch['default_classes']
      branch['entries'].each do |entry|
        dn = Chef::Recipe::LDAPUtils.build_dn(entry['dn'], branch_dn)
        attrs = entry
        attrs.delete('dn')

        # Generate the objectClass attribute if no specific one is specified on the current entry
        # Also make sure that this attribute is the first one within the hash (it would be ignored otherwise)
        if (!attrs.has_key? 'objectClass')
          attrs = { objectClass: default_classes }.merge(attrs)
        end

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
    [node['ca_openldap']['rootdn'], node['ca_openldap']['basedn']].join(',')
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
    case tls_mode.to_sym
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

  # Determine if TLS connexion are enable.
  # @param tls_mod the TLS mode, the following values are supported
  #   * :no - TLS connections are not supported, only clear connections are supported
  #   * :yes- TLS and clear connections are supported
  #   * :exclusive - only TLS connections are supported
  # @return [Boolean.true | Boolean.false] true if TLS mode is enable false ortherwise.
  #   
  #    
  def tls_enable?(tls_mode)
    result = use_ldap_or_ldaps? tls_mode
    result.last == "yes"
  end

  # Build the SLAPD sysconfig string that defines the URLS to listen to.
  #
  # It is based on 
  #  * node['ca_openldap']['tls']['enable'] : which protocol to listen to ?
  #  * node['ca_openldap']['slapd_listen_addresses'] : which IP/FQDN to listen to for LDAP/LDAPS protocol ?
  #  * node['ca_openldap']['enable_ldapi'] : Listen to LDAPI ?
  #
  #  @return [String] List of listen URLs
  def slapd_listen_urls
    urls = []

    (use_ldap, use_ldaps) = use_ldap_or_ldaps?(node['ca_openldap']['tls']['enable'].to_sym)
    ldap_port = node['ca_openldap']['default_ports']['ldap']
    ldaps_port = node['ca_openldap']['default_ports']['ldaps']

    urls << "ldapi:///" if node['ca_openldap']['enable_ldapi']

    if use_ldap == 'yes'
      node['ca_openldap']['slapd_listen_addresses'].each do |listen_adress|
        urls << "ldap://#{ listen_adress }:#{ ldap_port }"
      end
    end

    if use_ldaps == 'yes'
      node['ca_openldap']['slapd_listen_addresses'].each do |listen_adress|
        urls << "ldaps://#{ listen_adress }:#{ ldaps_port }"
      end
    end

    urls.join " "
  end

  # Retrieve initial slapd DB configuration file path.
  def slapd_init_db_config_file
    Dir["#{node['ca_openldap']['config_dir']}/cn=config/olcDatabase=\{*\}{hdb,bdb,mdb}.ldif"].first
  end

  # Retrieve initial slapd DB backend.
  def slapd_init_db_backend
    slapd_init_db_path_matcher[2]
  end

  # Retrieve initial slapd DB configuration index.
  def slapd_init_db_index
    slapd_init_db_path_matcher[1]
  end

  # Retrieve actual slapd DB configuration file path.
  def slapd_db_config_file
    Dir["#{node['ca_openldap']['config_dir']}/cn=config/olcDatabase=\{*\}{#{ node['ca_openldap']['db_backend'] }}.ldif"].first
  end

  # Retrieve actual slapd DB configuration index.
  def slapd_db_config_index
    ::File.basename(slapd_db_config_file).match(/{(\d+)}#{ node['ca_openldap']['db_backend'] }\.ldif/)[1]
  end

  private

  # Apply regular expression to slapd DB coonfiguration file name in order
  # to retrieve :
  # match group 1 : index
  # match group 2 : backend
  #
  # @return [Array<String>] The related matcher.
  def slapd_init_db_path_matcher
    basename = ::File.basename(slapd_init_db_config_file)
    basename.match(/\{(\d+)\}(hdb|bdb|mdb)\.ldif/) or raise "#{ basename } does not match expected slapd DB configuration file. Check slapd is properly installed."
  end

  # Extract data bag and data bag item name for populate from attribute.
  def populate_data_bag_item_name
    data_bag, item = node['ca_openldap']['populate']['databag_item_name'].split ":"

    if data_bag == nil or item == nil 
      raise "Attribute node['ca_openldap']['populate']['databag_item_name'] is mal formatted, expected <datab_bag>:<item>, example ca_openldap:populate"
    end 

    return [data_bag, item]
  end
end
