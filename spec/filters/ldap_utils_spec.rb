# encoding: utf-8
require_relative '../spec_helper'
require "logstash/filters/ldap"

describe LDAPUtils do
    before(:each) do
        @objectsid_bin = "\x01\x05\x00\x00\x00\x00\x00\x05\x15\x00\x00\x00m'\xE3\xE6\x01q\xFCd\xE2OR\xF2O\x83\x00\x00"
        @objectsid_str = "S-1-5-21-3873646445-1694265601-4065480674-33615"
        @objectguid_bin = "\x80\x14\x89\x033VkD\x828mD\x00Q\x85X"
        @objectguid_str = "03891480-5633-446b-8238-6d4400518558"
    end
    describe "get_sid_string" do
        it "gets the string representation of a sid hex" do
            expect(LDAPUtils::get_sid_string(@objectsid_bin)).to eq(@objectsid_str)
        end
    end
    describe "get_sid_strings" do
        it "gets the string representation of an array of sid hexes" do
            expect(LDAPUtils::get_sid_strings([@objectsid_bin,@objectsid_bin])).to eq([@objectsid_str,@objectsid_str])
        end
    end
    describe "unpack_guid" do
        it "gets the string representation of a guid hex" do
            expect(LDAPUtils::unpack_guid(@objectguid_bin)).to eq(@objectguid_str)
        end
    end
    describe "unpack_guids" do
        it "gets the string representation of an array of guid hexes" do
            expect(LDAPUtils::unpack_guids([@objectguid_bin,@objectguid_bin])).to eq([@objectguid_str,@objectguid_str])
        end
    end
    describe "get_cn" do
        it "gets the cn from a dn" do
            expect(LDAPUtils::get_cn('CN=ada lovelace,OU=users,DC=example,DC=com')).to eq('ada lovelace')
        end
    end
    describe "get_cns" do
        it "gets the cns from an array of dns" do
            expect(LDAPUtils::get_cns(['CN=ada lovelace,OU=users,DC=example,DC=com', 'CN=carl gauss,OU=users,DC=example,DC=com' ])).to eq(['ada lovelace', 'carl gauss'])
        end
    end
end
