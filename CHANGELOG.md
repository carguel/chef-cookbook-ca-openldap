# CHANGELOG for ca_openldap

This file is used to list changes made in each version of ca_openldap.

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
