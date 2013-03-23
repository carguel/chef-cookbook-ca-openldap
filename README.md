ca\_openldap Chef Cookbook
==========================

Configures a server to be an OpenLDAP server or OpenLDAP client.
Installs specific schema, creates a DIT and populates the directory.

This cookbooks only supports OpenLDAP 2.4+, as it is based on the new on line configuration method.

## Requirements

### Platform:

RedHat and CentOS 6.0+ are the target platforms.
Debian and Ubuntu are planned but currently not supported.

### Cookbooks:

None.

## Attributes

TODO

## Recipes

### server

Sets up a slapd daemon, by installing the relevant packages provided by the distribution.

### client

Install the OpenLDAP client packages and configures access to an OpenLDAP Server.

### dit

Installs the DIT based on a provided data bag item.

### schemas

Installs additional schemas provided as a file distribution (from another cookbook for example).

### populate

Populates the directory based on a provided data bag item.

License and Author
==================

Author:: Christophe Arguel (<christophe.arguel@free.fr>)
Copyright:: 2013, Christophe Arguel.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
