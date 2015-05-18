require 'spec_helper'
require 'global_config_options'
require 'tempfile'

module CaOpenldap
  describe GlobalConfigOptions do

    let(:reference_config_file) { File.expand_path("../../fixtures/cn=config.ldif", __FILE__) }
    let(:config_file) { Tempfile.new('rspec') }

    before(:each) do
      File.open(config_file, "w") do |file|
        file.write File.read(reference_config_file)
      end
      config_file.close
    end

    after(:each) do
      config_file.unlink
    end

    subject { GlobalConfigOptions.new(config_file.path) }

    describe "#new" do
      
      it "loads olc options from given configuration file" do
        expect(subject.options['olcAllows']).to eq "bind_v2"
        expect(subject.options['olcConcurrency']).to eq "0"
        expect(subject.options['olcConnMaxPending']).to eq "100"
      end

      it "only interprets lines starting with olc as options" do
        expect(subject.number_of_options).to eq 3
      end
    end

    describe "#set" do
      it "adds the option it does not exist" do
        subject.set("myOption", "myValue")
        expect(subject.options["myOption"]).to eq "myValue"
      end

      it "updates the option if it already exists" do
        subject.set("olcAllows", "")
        expect(subject.options["olcAllows"]).to eq ""
      end
    end

    describe "#delete" do
      it "deletes the option" do
        subject.delete("olcAllows")
        expect(subject.options).not_to include "olcAllows"
      end
    end

    describe "save" do
      it "updates the options in the file" do
        subject.set("myOption", "myValue")
        subject.save()

        reference_lines = File.read(reference_config_file).split /\n/
        actual_lines = File.read(config_file.path).split /\n/

        reference_lines.each do |reference_line|
          expect(actual_lines).to include reference_line
        end

        expect(actual_lines).to include "myOption: myValue"
      end

      context "when no option are changed" do
        it "returns false" do
          subject.set("olcAllows", "bind_v2")
          expect(subject.save).to eq false
        end
      end

      context "when some options are changed" do
        it "returns true" do
          subject.set("olcAllows", "bind_v3")
          expect(subject.save).to eq true
        end
      end
    end

  end
end
