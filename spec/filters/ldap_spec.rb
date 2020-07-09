# encoding: utf-8

require_relative '../spec_helper'
require "logstash/filters/ldap"
require 'net/ldap/entry'
require 'net/ldap'

# We disable warning for warning of others dependencies
$VERBOSE = nil

describe LogStash::Filters::Ldap do

  # You need to set-up all those environement variables to
  # test this plugin using "bundle exec rspect"
  before(:each) do
    @ldap_host='localhost'
    @bind_dn='cn=user,dc=example,dc=com'
    @bind_password='password'
    @base_dn='dc=example,dc=com'
    tesla_ldif = <<-LDIF.gsub(/^\s+/, "")
      dn: uid=tesla,dc=example,dc=com
      objectClass: inetOrgPerson
      objectClass: organizationalPerson
      objectClass: person
      objectClass: top
      objectClass: posixAccount
      cn: Nikola Tesla
      sn: Tesla
      uid: tesla
      mail: tesla@ldap.forumsys.com
      uidNumber: 88888
      gidNumber: 99999
      homeDirectory: home
    LDIF
    lovelace_ldif = <<-LDIF.gsub(/^\s+/, "")
      dn: CN=ada lovelace,OU=users,OU=TESTCASE,DC=example,DC=com
      objectClass: top
      objectClass: person
      objectClass: organizationalPerson
      objectClass: user
      cn: ada lovelace
      sn: lovelace
      givenName: ada
      distinguishedName: CN=ada lovelace,OU=users,OU=TESTCASE,DC=example,DC=com
      displayName: ada lovelace
      name: ada lovelace
      objectGUID:: gBSJAzNWa0SCOG1EAFGFWA==
      primaryGroupID: 33616
      objectSid:: AQUAAAAAAAUVAAAAbSfj5gFx/GTiT1LyT4MAAA==
      accountExpires: 9223372036854775807
      sAMAccountName: testlovelace
      sAMAccountType: 805306368
      userPrincipalName: testlovelace@example.com
      objectCategory: CN=Person,CN=Schema,CN=Configuration,DC=example,DC=com
    LDIF
    membership_ldif = <<-LDIF.gsub(/^\s+/, "")
      dn: uid=user,dc=example,dc=com
      objectClass: person
      objectClass: top
      objectClass: posixAccount
      cn: User of a Group
      sn: User
      uid: user
      memberOf: cn=group1,ou=test,dc=example,dc=com
      memberOf: cn=group2,ou=foo,dc=example,dc=com
      memberOf: cn=group3,ou=bar,dc=example,dc=com
      memberOf: cn=group4,ou=fizz,dc=example,dc=com
      memberOf: cn=group5,ou=buzz,dc=example,dc=com
    LDIF
    @membership_entry = Net::LDAP::Entry.from_single_ldif_string(membership_ldif)
    @lovelace_entry = Net::LDAP::Entry.from_single_ldif_string(lovelace_ldif)
    @tesla_entry = Net::LDAP::Entry.from_single_ldif_string(tesla_ldif)
    allow_any_instance_of(Net::LDAP).to receive(:bind).with(no_args).and_yield(true)
    allow_any_instance_of(Net::LDAP).to receive(:search).with(any_args)
  end

  describe "anonymous authentication" do
    let(:plugin) { ::LogStash::Filters::Ldap.new("ldap_filter" => "ou=mathematicians", "host" => "#{@ldap_host}", "base_dn" => "#{@base_dn}") }
    before do
      expect_any_instance_of(Net::LDAP).not_to receive(:auth).with(any_args)
    end

    it "should not call the auth method" do
      plugin.register
    end
  end

  describe "simple authentication" do
    let(:plugin) { ::LogStash::Filters::Ldap.new("ldap_filter" => "ou=mathematicians", "host" => "#{@ldap_host}", "base_dn" => "#{@base_dn}", "bind_dn" => "#{@bind_dn}", "bind_password" => "#{@bind_password}") }
    before do
      expect_any_instance_of(Net::LDAP).to receive(:auth).with(@bind_dn, @bind_password)
    end

    it "should call the auth function" do
      plugin.register
    end
  end

  describe "custom port" do
    let(:plugin) { ::LogStash::Filters::Ldap.new("ldap_filter" => "ou=mathematicians", "host" => "#{@ldap_host}", "base_dn" => "#{@base_dn}", "port" => 12345) }
    before do
      allow(plugin.logger).to receive(:info).with(any_args)
    end

    it "should use the custom port" do
      plugin.register
      expect(plugin.logger).to have_received(:info).with("binding to #{@ldap_host}:#{12345}") # there is probably a better way to test this
    end
  end

  describe "default ssl port" do
    let(:plugin) { ::LogStash::Filters::Ldap.new("ldap_filter" => "ou=mathematicians", "host" => "#{@ldap_host}", "base_dn" => "#{@base_dn}", "ssl" => true) }
    before do
      allow(plugin.logger).to receive(:info).with(any_args)
    end

    it "should use the custom port" do
      plugin.register
      expect(plugin.logger).to have_received(:info).with("binding to #{@ldap_host}:#{636}") # there is probably a better way to test this
    end
  end

  describe "default non-ssl port" do
    let(:plugin) { ::LogStash::Filters::Ldap.new("ldap_filter" => "ou=mathematicians", "host" => "#{@ldap_host}", "base_dn" => "#{@base_dn}", "ssl" => false) }
    before do
      allow(plugin.logger).to receive(:info).with(any_args)
    end

    it "should use the custom port" do
      plugin.register
      expect(plugin.logger).to have_received(:info).with("binding to #{@ldap_host}:#{389}") # there is probably a better way to test this
    end
  end

  describe "filter syntax error handling" do
    let(:plugin) { ::LogStash::Filters::Ldap.new("ldap_filter" => "a%{bad\\filt*er", "host" => "#{@ldap_host}", "base_dn" => "#{@base_dn}", "ssl" => false) }
    let(:event) { ::LogStash::Event.new }
    before do
      plugin.register
      allow(plugin.logger).to receive(:error).with(any_args)
    end

    it "should not throw an error when filtering" do
      expect do
        plugin.filter(event)
      end.not_to raise_error
    end

    it "should log an error" do
      plugin.filter(event)
      expect(plugin.logger).to have_received(:error).with(/Invalid filter syntax/)
    end
  end

  describe "simple search filter" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "#{@base_dn}"
          ldap_filter => "uid=tesla"
          include_error_message => true
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:filter => Net::LDAP::Filter.construct('uid=tesla'))).and_yield(@tesla_entry)
    end

    sample("message" => "some text") do
      expect(subject.get('[ldap][uid]')).to eq(['tesla'])
      expect(subject.get('[ldap][sn]')).to eq(['Tesla'])
      expect(subject.get('[ldap][cn]')).to eq(['Nikola Tesla'])
      expect(subject.get('[ldap][mail]')).to eq(['tesla@ldap.forumsys.com'])
      expect(subject.get('[ldap][uidnumber]')).to eq(['88888'])
      expect(subject.get('[ldap][gidnumber]')).to eq(['99999'])
      expect(subject.get('[ldap][homedirectory]')).to eq(['home'])
      expect(subject.get('[ldap][objectclass]')).to include('inetOrgPerson','organizationalPerson','person','top','posixAccount')
    end
  end

  describe "search with multiple matches" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "#{@base_dn}"
          ldap_filter => "(|(uid=tesla)(sAMAccountName=testlovelace))"
          include_error_message => true
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:filter => Net::LDAP::Filter.construct("(|(uid=tesla)(sAMAccountName=testlovelace))"))).and_yield(@tesla_entry).and_yield(@lovelace_entry)
    end

    sample("message" => "some text") do
      expect(subject.get('[ldap][uid]')).to include('tesla')
      expect(subject.get('[ldap][sn]')).to include('Tesla','lovelace')
      expect(subject.get('[ldap][cn]')).to include('Nikola Tesla', 'ada lovelace')
      expect(subject.get('[ldap][mail]')).to include('tesla@ldap.forumsys.com')
      expect(subject.get('[ldap][uidnumber]')).to include('88888')
      expect(subject.get('[ldap][gidnumber]')).to include('99999')
      expect(subject.get('[ldap][homedirectory]')).to include('home')
      expect(subject.get('[ldap][name]')).to include('ada lovelace')
      expect(subject.get('[ldap][samaccountname]')).to include('testlovelace')
      expect(subject.get('[ldap][objectclass]')).to include('inetOrgPerson','organizationalPerson','person','top','posixAccount', 'user')
    end
  end

  describe "search with multiple matches and limited to one" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "#{@base_dn}"
          ldap_filter => "(|(uid=tesla)(sAMAccountName=testlovelace))"
          include_error_message => true
          match_first => 1
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:filter => Net::LDAP::Filter.construct("(|(uid=tesla)(sAMAccountName=testlovelace))"))).and_yield(@tesla_entry).and_yield(@lovelace_entry)
    end

    sample("message" => "some text") do
      expect(subject.get('[ldap][uid]')).to include('tesla')
      expect(subject.get('[ldap][sn]')).to include('Tesla')
      expect(subject.get('[ldap][sn]')).not_to include('lovelace')
      expect(subject.get('[ldap][samaccountname]')).to eq(nil)
    end
  end

  describe "escaped sprintf values" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "#{@base_dn}"
          ldap_filter => "(cn=%{message})"
          include_error_message => true
          escape_sprintf_values => true
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:filter => Net::LDAP::Filter.construct('(cn=Nikola*)'))).and_yield(@tesla_entry)
    end

    sample("message" => "Nikola*") do
      expect(subject.get('[ldap][uid]')).not_to eq(['tesla'])
    end
  end

  describe "unescaped sprintf values" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "#{@base_dn}"
          ldap_filter => "(cn=%{message})"
          include_error_message => true
          escape_sprintf_values => false
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:filter => Net::LDAP::Filter.construct("(cn=Nikola*)"))).and_yield(@tesla_entry)
    end

    sample("message" => "Nikola*") do
      expect(subject.get('[ldap][uid]')).to eq(['tesla'])
    end
  end

  describe "base_dn using sprinf format" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "%{message}"
          ldap_filter => "uid=tesla"
          include_error_message => true
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:base => "#{@base_dn}")).and_yield(@tesla_entry)
    end

    sample("message" => "dc=example,dc=com") do
      expect(subject.get('[ldap][uid]')).to eq(['tesla'])
    end
  end

  describe "using group membership" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "#{@base_dn}"
          ldap_filter => "(uid=user)"
          include_error_message => true
          extract_membership => true
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:filter => Net::LDAP::Filter.construct("(uid=user)"))).and_yield(@membership_entry)
    end

    sample("message" => "some text") do
      expect(subject.get('[ldap][membership]')).to include('group1', 'group2', 'group3', 'group4', 'group5')
    end
  end

  describe "without using group membership" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "#{@base_dn}"
          ldap_filter => "(uid=user)"
          include_error_message => true
          extract_membership => false
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:filter => Net::LDAP::Filter.construct("(uid=user)"))).and_yield(@membership_entry)
    end

    sample("message" => "some text") do
      expect(subject.get('[ldap][membership]')).to eq(nil)
    end
  end

  describe "microsoft AD compatibility" do
    let(:config) do <<-CONFIG
      filter {
        ldap {
          host => "#{@ldap_host}"
          base_dn => "#{@base_dn}"
          ldap_filter => "(sAMAccountName=testlovelace)"
          include_error_message => true
        }
      }
    CONFIG
    end

    before do
      allow_any_instance_of(Net::LDAP).to receive(:search).with(hash_including(:filter => Net::LDAP::Filter.construct("(sAMAccountName=testlovelace)"))).and_yield(@lovelace_entry)
    end

    sample("message" => "some text") do
      expect(subject.get('[ldap][objectsid]')).to include('S-1-5-21-3873646445-1694265601-4065480674-33615')
      expect(subject.get('[ldap][objectguid]')).to include('03891480-5633-446b-8238-6d4400518558')
    end
  end

end
