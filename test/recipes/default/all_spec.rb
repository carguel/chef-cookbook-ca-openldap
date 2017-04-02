# # encoding: utf-8

# Inspec test for recipe ccs_serveur_rejeu::default

# The Inspec reference, with examples and extensive documentation, can be
# found at https://docs.chef.io/inspec_reference.html

describe service('slapd') do
  it { should be_enabled }
  it { should be_running }
end

describe command('slapcat') do
  its(:stdout) { should cmp(/ou=users,dc=example,dc=com/) }
  its(:stdout) { should cmp(/uid=new_entry,ou=users,dc=example,dc=com/) }
end
