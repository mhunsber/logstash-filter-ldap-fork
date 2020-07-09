require 'net/ldap/dn'

module LDAPUtils
    # https://github.com/ruby-ldap/ruby-net-ldap/issues/222
    @B32 = 2**32
    def self.get_sid_string(data)
      sid = data.unpack('b x nN V*')
      sid[1, 2] = Array[nil, b48_to_fixnum(sid[1], sid[2])]
      'S-' + sid.compact.join('-')
    end

    def self.get_sid_strings(arr)
      arr.map { |data| 
        get_sid_string(data)
      }
    end

    def self.b48_to_fixnum(i16, i32)
      i32 + (i16 * @B32)
    end

    # http://astockwell.com/blog/2015/06/active-directory-objectguid-queries-ruby-python/
    def self.to_oracle_raw16(string, strip_dashes=true, dashify_result=false)
      oracle_format_indices = [3, 2, 1, 0, 5, 4, 7, 6, 8, 9, 10, 11, 12, 13, 14, 15]
      string = string.gsub('-'){ |match| '' } if strip_dashes
      parts = split_into_chunks(string)
      result = oracle_format_indices.map { |index| parts[index] }.reduce('', :+)
      if dashify_result
          result = [result[0..7], result[8..11], result[12..15], result[16..19], result[20..result.size]].join('-')
      end
      return result
    end

    def self.split_into_chunks(string, chunk_length=2)
        chunks = []
        while string.size >= chunk_length
            chunks << string[0, chunk_length]
            string = string[chunk_length, string.size]
        end
        chunks << string unless string.empty?
        return chunks
    end

    def self.pack_guid(string)
        [to_oracle_raw16(string)].pack('H*')
    end

    def self.unpack_guid(hex)
        to_oracle_raw16(hex.unpack('H*').first, true, true)
    end

    def self.unpack_guids(arr)
      arr.map { |hex| 
        unpack_guid(hex)
      }
    end

    def self.get_cn(dn_s)
      dn = Net::LDAP::DN.new(dn_s)
      dn_h = dn.enum_for(:each_pair).map { |key, value| [key.downcase, value] }.to_h
      dn_h['cn']
    end

    def self.get_cns(dns)
        dns.map { |dn_s|
            get_cn(dn_s)
        }
    end
end