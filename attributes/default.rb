# Default base dn
default.ca_openldap.basedn = "dc=example,dc=com"

# Default openldap server
default.ca_openldap.ldap_server = "localhost"

# Default openldap port
default.ca_openldap.ldap_port = "389"

default.ca_openldap.db_dir = "/var/lib/ldap"

# Default rootDN
default.ca_openldap.rootdn = "cn=Manager,#{node.ca_openldap.basedn}"

# Default rootPassword, will be stored in SSHA
# It should be overriden by a role attribute
default.ca_openldap.rootpassword = "pa$$word"

# Default log level of the accesses to the bdb database
default.ca_openldap.ldap_log_level = "-1"

# Default ACL
default.ca_openldap.acls = ["to attrs=userPassword by self =xw by anonymous auth by * none", 
                            "to * by self write by users read by * none"]

# Default cookbook which defines the schemas to import
# The cookbook shall store these schemas under files/default/schemas/
# Each schema file shall have a .schema extension
default.ca_openldap.schema_cookbook = nil

# Default additional schemas to import
default.ca_openldap.additional_schemas = []

# Default classes for users
default.ca_openldap.user_classes = %W[top inetOrgPerson posixAccount]

# Default DIT to create in the directory.
# This attribute can be overriden by the 'ca_openldap/dit' data bag item.
# If this data bag item exists, the DIT is searched under the "dit" hash key.
# Each entry of the DIT is defined by an hash, where:
# - the key is the part of the DN relative to its parent
# - the value is a hash including the following keys:
#   - "attrs": hash defining all attributes of the entry
#   - "children": hash of the children entries
default.ca_openldap.dit = {
  "#{node.ca_openldap.basedn}" => {
    attrs: {
      objectClass: ["organization", "dcObject"], 
      description: "DN description", 
      o: "organization"
    },
    children: {
      "ou=users" => {
        attrs: {
          objectClass: %W[top organizationalUnit]
        }
      },
      "ou=groups" => {
        attrs: {
          objectClass: %W[top organizationalUnit]
        }
      },
      "ou=policies" => {
        attrs: {
          objectClass: %W[top organizationalUnit]
        }
      }
    }
  }
}

# Root directory of the openldap configuration
default.ca_openldap.root_dir = "/etc/openldap"

# Root directory of the slapd configuration
default.ca_openldap.config_dir = "{node.ca_openldap.root_dir}/slapd.d"

# DN of the default ppolicy configuration
default.ca_openldap.ppolicy_default_config_dn = "cn=passwordDefault,ou=policies,#{node.ca_openldap.basedn}"

# Default ppolicy configuration (supported attributes are defined by section "Object Class Attributes" in slapo-ppolicy(5))
default.ca_openldap.ppolicy_default_config = {
  pwdAllowUserChange: "TRUE",
  pwdAttribute: "userPassword",
  pwdCheckQuality: "0",
  pwdMinAge: "0",
  pwdMaxAge: "0",
  pwdMinLength: "5",
  pwdInHistory: "5",
  pwdMaxFailure: "3",
  pwdFailureCountInterval: "0",
  pwdLockout: "TRUE",
  pwdLockoutDuration: "0",
  pwdAllowUserChange: "TRUE",
  pwdExpireWarning: "0",
  pwdGraceAuthNLimit: "0",
  pwdMustChange: "FALSE",
  pwdSafeModify: "TRUE"
}
