require 'spec_helper'
require 'net/ldap'

$LOAD_PATH.unshift(File.expand_path('../../../libraries', __FILE__))
require 'ldap_utils'


class Chef::Recipe
  describe LDAPUtils do
    let(:host) { 'server' }
    let(:port)  { 389 }
    let(:dn) { 'cn=Manager,dc=example,dc=com' }
    let(:password) { 'guess_me' }
    let(:tls_enable) { false }

    let(:ldap) { double }

    subject { LDAPUtils.new(host, port, dn, password, tls_enable) }

    before(:each) do
      expect(::Net::LDAP).to receive(:new).with(args).and_return(ldap)
    end

    let(:args) do
      {
        host: host,
        port: port,
        auth: {
          method: :simple, 
          username: dn,
          password: password
        }
      }
    end

    let(:attrs) { {cn: 'user', userPassword: 'guess_me', description: 'description'} } 
    let(:dn_to_add) { 'cn=user,dc=example,dc=com' }
    let(:return_result) { false }
    let(:search_result) { nil }
    let(:operation_result) { nil }

    before(:each) do
      class Chef::Log
      end
      allow(Chef::Log).to receive :info
      allow(ldap).to receive(:get_operation_result).and_return(operation_result)
    end

    describe "#add_entry" do
      before(:each) do
        allow(ldap).to receive(:search).with(base: dn_to_add, scope: Net::LDAP::SearchScope_BaseObject, return_result: false).and_return(search_result)
      end

      context "entry does not exist" do
        it "add the entry through the NET::Ldap instance" do
          expect(ldap).to receive(:add).with(dn: dn_to_add, attributes: attrs).and_return(true)
          subject.add_entry(dn_to_add, attrs)
        end
      end

      context "entry already exists" do
        let(:search_result) { ["found"] }

        it "does not add the entry through the NET::Ldap instance" do
          expect(ldap).not_to receive(:add).with(dn: dn_to_add, attributes: attrs)
          subject.add_entry(dn_to_add, attrs)
        end
      end
    end

    describe "#add_or_update_entry" do
      before(:each) do
        allow(ldap).to receive(:search).with(base: dn_to_add, scope: Net::LDAP::SearchScope_BaseObject, return_result: true).and_return([attrs])
      end

      context "entry already exist" do
        context "some attributes are modified" do
          let(:new_password) { 'new_password' }
          let(:updated_attrs) do
            {}.merge(attrs).merge(userPassword: new_password)
          end
          let(:expected_operations) do
            [
              [
                :replace,
                :userPassword,
                new_password
              ]
            ]
          end

          before(:each) do
            expect(ldap).to receive(:modify).with(
              dn: dn_to_add,
              operations: expected_operations 
            ).and_return(true)
          end

          context "the list of ignored attributes is empty" do
            it "updates only the modified attributes of the entry" do
              subject.add_or_update_entry(dn_to_add, updated_attrs)
            end
          end

          context "some modified attributes are in the ignored list" do
            let(:other_updated_attrs) do
              {}.merge(updated_attrs).merge(description: 'modified_description')
            end

            ['description', 'DESCRIPTION', :description].each do |attribute_name|
              it "does not update the ignored attribute (#{attribute_name.inspect})" do
                subject.add_or_update_entry(dn_to_add, other_updated_attrs, attribute_name)
              end
            end
          end
        end

        context "no attributes are modified" do
          it "does not update the entry" do
            expect(ldap).not_to receive(:modify)
            subject.add_or_update_entry(dn_to_add, attrs)
          end
        end
      end
    end
  end
end
