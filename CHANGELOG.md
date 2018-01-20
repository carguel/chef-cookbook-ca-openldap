# CHANGELOG for ca_openldap

This file is used to list changes made in each version of ca_openldap.

## 0.6.0
 * Support RHEl/CentOS 7
 * Add custom resource 'entry' to create an entry in LDAP server.
 * Remove warnings raised by Chef 12
 * Support configuring populate data bag item name
 * Create new recipe 'acl' to set up ACLs (ACL are no longer set by 'server' recipe). This allows to configure ACLs on specific LDAP attributes after importing related schemas with 'schema' recipe. 
 * Fix minor issues

## 0.5.2
 * Fix #16: Log message should filter password value.

## 0.5.1
 * Fix #15: set root as owner of /etc/openldap/cacerts to prevent error when ldap user does not exist.

## 0.5
 * Add support for slapd general configuration options (cn=config)

## 0.4.2
* Fix unwanted attribute when creating an entry (#12)
* Fix wrong management of ['ca_openldap']['populate']['attributes_to_ignore'] (#11)

## 0.4.1
* Stringify and convert in lowercase attribute names for the evaluation
  of attributes to ignore.

## 0.4
* Support a list of attributes not to update in populate recipe (#7)

## 0.3
* Raise an exception when entry update fails (#6)
* Fix error when creating DIT if TLS mode is not enable (#7)
* Add support for update mode in populate recipe (#8)
* Fix wrong URI in ldap.conf file (#9)
* Fix error in ppolicy recipe when TLS is not enable (#7)

## 0.2.3
* Replace gem dependency to activeldap by ssha.
* Allow installation of net-ldap and ssh gems providing path of local gems.
* Force conversion to symbol of node['ca_openldap']['tls']['enable'] value.

## 0.2.2:
* Manage configuration of default listening ports
* Add a recipe to install and configure ppolicy overlay
* Define Apache 2.0 as the license of this cookbook

## 0.2.1:

* Fix #2: Compile Error in server recipe on file resource node.ca_openldap.tls.key_file
* Fix #1: Wrong rootdn used for the ppolicy configuration creation

## 0.2.0:

* Add TLS support based on the certificates and the related key file 
previously deployed by the _certificate_ cookbook (see attribute `use_existing_certs_and_key`)
* Improve the documentation (see README.md)

## 0.1.0:

* Initial release of ca_openldap

- - -
Check the [Markdown Syntax Guide](http://daringfireball.net/projects/markdown/syntax) for help with Markdown.

The [Github Flavored Markdown page](http://github.github.com/github-flavored-markdown/) describes the differences between markdown on github and standard markdown.
