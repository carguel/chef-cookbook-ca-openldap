require 'spec_helper'
require 'ca_openldap'

class Chef::Recipe

  describe CAOpenldap do

    let(:node_definition) do
      {
        'ca_openldap' => {
          'enable_ldapi' => true,
          'slapd_listen_addresses' => ['ldap.example.com'],
          'default_ports'=> {
            'ldap' => 389,
            'ldaps' => 636
          },
          'tls' => {
            'enable' => :exclusive
          }
        }
      }
    end

    subject do 
      node_def = node_definition
      subject = Class.new.new
      subject.define_singleton_method(:node) { node_def }
      subject.send(:extend, CAOpenldap)
    end

    describe "#slapd_listen_urls" do

      context 'when ldaps is not enabled' do
        before do 
          node_definition['ca_openldap']['tls']['enable'] = :no
        end

        it "returns a string including ldapi:/// and ldap:// URLs" do
          expect(subject.slapd_listen_urls).to eq "ldapi:/// ldap://ldap.example.com:389"
        end
      end

      context 'when both ldap and ldaps are enabled' do
        before do 
          node_definition['ca_openldap']['tls']['enable'] = :yes
        end

        it "returns a string including ldapi:/// and ldap:// URLs" do
          expect(subject.slapd_listen_urls).to eq "ldapi:/// ldap://ldap.example.com:389 ldaps://ldap.example.com:636"
        end
      end

      context 'when ldaps exclusively enabled' do
        before do 
          node_definition['ca_openldap']['tls']['enable'] = :exclusive
        end

        it "returns a string including ldapi:/// and ldaps:// URLs" do
          expect(subject.slapd_listen_urls).to eq "ldapi:/// ldaps://ldap.example.com:636"
        end
      end

      context 'when ldapi and ldaps are not enabled' do
        before do 
          node_definition['ca_openldap']['tls']['enable'] = :no
          node_definition['ca_openldap']['enable_ldapi'] = false
        end

        it "returns a string including ldap:// URLs" do
          expect(subject.slapd_listen_urls).to eq "ldap://ldap.example.com:389"
        end

      end
    end
  end
end
