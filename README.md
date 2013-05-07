ca\_openldap Chef Cookbook
==========================

This cookbook provides several recipes to perform the following actions:
* configure a node to be an OpenLDAP server or OpenLDAP client,
* import specific schemas, 
* create a DIT, 
* configure the PPolicy module
* enable TLS support
* populate the directory.

This cookbooks only supports OpenLDAP 2.4+, as it is based on the new on line configuration method.

## Requirements

### Platform:

RedHat and CentOS 6.0+ are the target platforms.
Debian and Ubuntu are planned but currently not supported.

### Cookbooks:

* [certificate](http://community.opscode.com/cookbooks/certificate) (optional): ca\_openldap supports the certificates and the related key file deployed with this cookbook.

## Attributes

### Common attributes

* `node.ca_openldap.basedn` - base DN of the directory (default: `"dc=example,dc=com"`).
* `node.ca_openldap.ldap_server` - IP or hostname of the node which hosts the ldap server (default: `"localhost"`).
* `node.ca_openldap.ldap_port` - TC port of the ldap server (default: `636`).

### Server attributes

* `node.ca_openldap.db_dir` - Directory where the DBD files are created (default: `"/var/lib/ldap"`).
* `node.ca_openldap.rootdn` - RootDN, relative to `node.ca_openldap.basedn` (default: `"cn=Manager"`)
* `node.ca_openldap.rootpassword` - Root Password, it is strongly recommended to modify the default value (default: `"pa$$word"`) 
* `node.ca_openldap.ldap_log_level` - Log level - see [Slapd config] (http://www.openldap.org/doc/admin24/slapdconfig.html) for explanation of supported values (default: `"-1"`)
* `node.ca_openldap.acls` - ACLs, this is a ruby Array of the ACL to create, each line must comply with the OpenLDAP ACL syntax (default allows to read any attributes (except password) from any authenticated users and to write any attributes that belongs to the current user)
* `node.ca_openldap.tls.enable` - Configure the TLS access support, accepted values are (default `:exclusive`): 
    * `:no` TLS access is not allowed
    * `:yes` both clear and TLS accesses are allowed
    * `:exclusive` only TLS access is allowed (`node.ca_openldap.ldap_port` shall be correctly set)
* `node.ca_openldap.tls.cacert_path` - Path of the directory where the CA certificates are stored (default: `"/etc/openldap/cacerts"`).
* `node.ca_openldap.tls.cert_file` - Path of the node certificate (default: `"/etc/openldap/certs/#{node.fqdn}.pem"`). 
* `node.ca_openldap.tls.key_file` - Path of the private key related to the node certificate (default: `"/etc/openldap/certs/#{node.fqdn}.key"`). 
* `node.ca_openldap.use_existing_certs_and_key` - boolean configuring the support of certificates deployed with the _certificate_ cookbook. When true, assume the CA certificate, the server certificate and its related key already exist under default directory set by the _certificate_ cookbook (/etc/pki/tls for RHEL). Consequently, the following links are created:
    * `node.ca_openldap.tls.cert_file`: points to the Server certificate (/etc/pki/tls/certs/\<fqdn\>.pem for RHEL).
    * `node.ca_openldap.tls.cacert_path + "/" + cacert_hash + ".0"`: points to the CA certificate chain (/etc/pki/tls/certs/\<_hostname_\>-bundle.crt for RHEL), cacert_hash is the X509 hash of the CA certificate file.
Additionally the key file (/etc/pki/tls/private/\<_fqdn_\>.key) is copied to `node.ca_openldap.tls.key_file`.

### PPolicy attributes
* `node.ca_openldap.ppolicy_default_config_dn` - DN where the default ppolicy configuration is stored, relatively to the `node.ca_openldap.basedn` (default: `"cn=passwordDefault,ou=policies"`).
* `node.ca\_openldap.ppolicy\_default\_config` - Default ppolicy configuration, supported attributes are defined by section "Object Class Attributes" in slapo-ppolicy(5) (check default value in `attributes/default.rb`)


### Schema attributes

* `node.ca_openldap.schema_cookbook` - cookbook name which includes additional schema do set up, schemas are search as cookbook distribution files, under files/default/schemas/ (default: nil)
* `node.ca_openldap.additional_schemas` - List of schemas to import in the directory, the suffix ".schema" is added to each item of the list to build the complete file name (default : [])

### DIT attributes
* `node.ca_openldap.dit` - JSON structure which defines the DIT, this attribute can be overriden by the `ca_openldap/dit` data bag item, see `dit` recipe for additional information.


## Recipes

### server

Sets up a slapd daemon on the current node.

This recipe performs the following actions:
* install the relevant packages provided by the distribution
* configure the base DN, root DN and root password according to the related attributes
* enable if requested the TLS support (see dedicated section below)
* set the base directory for the BDB files
* set the slapd log level
* configure ACLs 

### client

Install the OpenLDAP client packages and configure access to an OpenLDAP Server.

This recipe depends on the common attributes and the `node.ca_openldap.use_existing_certs_and_key` and `node.ca_openldap.tls.cacert_path`attributes.

### dit

Install the DIT based on a provided data bag item. 

The DIT is defined by the `ca_openldap/dit` data bag item if it exists, otherwise by the `node.ca_openldap.dit` attribute.

Each entry of the DIT is defined by an hash, where:
* the key is the part of the DN relative to its parent
* the value is a hash including the following keys:
    * `"attrs"`: hash defining all attributes of the entry
    * `"children"`: hash of the children entries

In the case of the data bag item, the DIT structure is found under the `"dit"` hash key.

Example of `ca_openldap/dit` data bag item:

```json
    {
      "id": "dit",
      "dit": {
        "dc=example,dc=fr": {
          "attrs": {
            "objectClass": ["organization", "dcObject"],
            "description": "root of the directory",
            "o": "organization"
          },
          "children": {
            "ou=groups": {
              "attrs": {
                "objectClass": ["top", "organizationalUnit"]
              }
            },
            "ou=users": {
              "attrs": {
                "objectClass": ["top", "organizationalUnit"]
              }
            }
          }
        }
      }
    }
```


### schemas

Install additional schemas provided as a file distribution (from another cookbook for example).

See the schema attributes above to configure this recipe.

Each provided schema file must comply with the standard schema format (have a look to the official schemas stored under /etc/openldap/schemas).

### populate

Populate the directory based on a provided data bag item.

The data bag item is `ca_openldap/populate`. This data bag item shall defines the following entries:
* a `"base"` which specify the DN to append to each consecutive branch DN
* a list of branches (under `"branches"`) . Each branch is defined by the following entries:
    * a `"name"` which defines the relative DN of the branch
    * a list of default classes (under `"default_classes"`) to apply to each consecutive entry
    * a list of entries (under `"entries"`), each item of this list defines an entry to create or update in the directory under the related branch. An item is a hash where keys and values maps the LDAP attribute names and values.

Example of `ca_openldap/populate` data bag item:

```json
    {
      "id": "populate",
      "base": "dc=example,dc=fr",
      "branches": [
        {
          "name": "ou=unixAccounts,ou=users",
          "default_classes": ["top", "posixAccount", "inetOrgPerson"],
          "entries": [
            {
              "dn": "uid=test1",
              "uidNumber": "12001",
              "uid": "test",
              "cn": "test",
              "gidNumber": "12001",
              "sn": "test user",
              "userPassword": "pa$$word",
              "homeDirectory": "/home/test"
            },
            {
              "dn": "uid=test2",
              "uidNumber": "12002",
              "uid": "test2",
              "cn": "test2",
              "gidNumber": "12002",
              "sn": "test user 2",
              "userPassword": "pa$$word",
              "homeDirectory": "/home/test2"
            }
          ]
        },
        {
          "name": "ou=groups",
          "default_classes": ["top", "posixGroup"],
          "entries": [
            {
              "dn": "cn=test1",
              "gidNumber": "12001",
              "memberUid": "test1"
            },
            {
              "dn": "cn=test2",
              "gidNumber": "12002",
              "memberUid": "test2"
            },
            {
              "dn": "cn=test",
              "gidNumber": "12000",
              "memberUid": ["test1", "test2"]
            }
          ]
        }
      ]
    }
```

### ppolicy

Configure the PPolicy module.

## TLS support

TLS support is managed by the `server` recipe and configured by the `node.ca_openldap.tls.*` attributes and `node.ca_openldap.use_existing_certs_and_key` attribute.
If `node.ca_openldap.use_existing_certs_and_key` is set to false, the recipe assumes that the server and CA certificates and the server key are already provided by another cookbook.
Note that openldap expects that CA certificate names should have their names of the form "xxxxx.0", where "xxxxx" is x509 hash of the certificate.

The x509 hash can be easily generated with the following command:

    openssl x509 -noout -hash -in /path/to/certificate.pem

If `node.ca_openldap.use_existing_certs_and_key` is set to true, 
the recipe assumes that the server and CA certificates 
were previously deployed by the _certificate_ cookbook under the default locations.
Consequently, the recipe creates two links which point to the server and CA certificates:
* the server certificate link is created under the `node.ca_openldap.tls.cert_file` location,
* the CA certification link is created in the `node.ca_openldap.tls.cacert_path` directory, with the proper name as explaine above.  
Additionaly, the recipe copies the server key to the `node.ca_openldap.tls.key_file` location.

Take care to correctly set the `node.ca_openldap.ldap_port` attribute 
to the LDAPS default port (636) when `node.ca_openldap.tls.enable_tls` is set to `:exclusive`, 
otherwise the `dit` and `populate` recipes will not work.

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
