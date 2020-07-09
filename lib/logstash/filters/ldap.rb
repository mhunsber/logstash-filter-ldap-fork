# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

require 'digest/md5'

require 'net/ldap'
require 'rufus-scheduler'

require_relative "buffer/cache_saver"
require_relative "buffer/memory_cache"
require_relative "helpers/ldap_utils"

class LogStash::Filters::Ldap < LogStash::Filters::Base

  config_name "ldap"

  # Definition of the filter config parameters
  config :ldap_filter, :validate => :string, :required => true

  config :target, :validate => :string, :required => false, :default => "ldap"
  config :attributes, :validate => :array, :required => false, :default => []
  config :extract_membership, :validate => :boolean, :required => false, :default => false
  config :escape_sprintf_values, :validate => :boolean, :required => false, :default => true
  config :match_first, :validate => :number, :required => false

  config :host, :validate => :string, :required => true
  config :ssl, :validate => :boolean, :required => false, :default => false
  config :port, :validate => :number, :required => false, :default => nil

  config :bind_dn, :validate => :string, :required => false
  config :bind_password, :validate => :password, :required => !@bind_dn.nil?

  config :base_dn, :validate => :string, :required => true

  config :use_cache, :validate => :boolean, :required => false, :default => true
  config :cache_type, :validate => :string, :required => false, :default => "memory"
  config :cache_memory_duration, :validate => :number, :required => false, :default => 300
  config :cache_memory_size, :validate => :number, :required => false, :default => 20000

  config :disk_cache_filepath, :validate => :string, :required => false, :default => nil
  config :disk_cache_schedule, :validate => :string, :required => false, :default => "10m"

  config :include_error_message, :validate => :boolean, :required => false, :default => false
  config :tag_on_failure, :validate => :array, :required => false, :default => [ "_ldapfiltererror" ]


  # Equivalent to 'initialize' method

  public
  def register

    # Setup some constants
    @SUCCESS = "LDAP_OK"
    @FAIL_PROCESSING = "LDAP_ERROR"
    @NOT_FOUND = "LDAP_NOT_FOUND"

    # Setup some variables
    @attributes_uppercase = @attributes.map(&:upcase)
    @search_all_attributes = (@attributes.length == 0)
    @uses_sprintf = !@ldap_filter.index(/%\{[^}]+\}/).nil?

    # Check if cache type selected is valid
    if @use_cache
      if @cache_type == "memory"
        @logger.info("Memory cache was selected")
        @Buffer = MemoryCache.new(@cache_memory_duration, @cache_memory_size)
      else
        @logger.warn("Unknown cache type: #{@cache_type}")
        @logger.warn("Cache utilisation will be disabled")
        @use_cache = false
      end
    end

    # Set-up of persitant cache
    if @use_cache and !disk_cache_filepath.nil?
      @logger.info("Cache persistance on disk is enabled")
      @disk_cache = CacheSaver.new(@disk_cache_filepath)

      # We load data if any
      succeed, data, error = @disk_cache.load()

      if succeed
        @Buffer.from_obj(data)
        @logger.info("Successfully loaded cache")
      else
        @logger.warn("Failed to load cache : #{error}")
      end

      # We start scheduling save of the cache
      begin
        scheduler.every @disk_cache_schedule do
          data = @Buffer.to_obj()
          succeed, error = @disk_cache.save(data)
          if succeed
            @logger.info("Successfully saved cache")
          else
            @logger.info("Failed to persist cache on disk : #{error}")
          end
        end
      rescue => e
        @logger.warn("Failed to persist cache on disk: #{e.message}")
      end
    end
    # Setup ldap connection
    @ldap = if @ssl then
      Net::LDAP.new :encryption => {
          :method => :simple_tls,
          :tls_options => { verify_mode: OpenSSL::SSL::VERIFY_NONE }
        }
    else
      Net::LDAP.new
    end
    @ldap.host = @host
    @ldap.port = @port || if @ssl then 636 else 389 end
    @ldap.auth @bind_dn, @bind_password.value if !@bind_dn.nil?

    # Check the state of the connection
    begin
      @logger.info("binding to #{@ldap.host}:#{@ldap.port}")
      if !@ldap.bind()
        raise(@ldap.get_operation_result.error_message)
      end
    rescue Exception => err
      @logger.error("Error while setting-up connection with LDAP server '#{@host}': #{err.message}")
    end
  end

  # This function is called each time an event should be processed
  public
  def filter(event)

    ldap_filter_string = if(@uses_sprintf) then
      # we should escape the sprintf results
      @ldap_filter.gsub(/%\{[^}]+\}/) do |tok|
        if @escape_sprintf_values then
          Net::LDAP::Filter.escape(event.sprintf(tok))
        else
          event.sprintf(tok)
        end
      end
    else
      @ldap_filter
    end
    cached = false

    if @use_cache

      # Check if the identifier is cached already via it's hash value
      identifier_hash = hashIdentifier(@host, @port, ldap_filter_string)

      # Get the cache result
      res = @Buffer.get(identifier_hash)
      if res.nil?
        res, exitstatus = ldapsearch(ldap_filter_string)
        # Store the result for futher use
        @Buffer.cache(identifier_hash, res)
      end

    else
      res, exitstatus = ldapsearch(ldap_filter_string)
    end

    # Add the result fetched from the database into current event

    res.each{|key, value|
      targetArray = event.get(@target)
      if targetArray.nil?
        targetArray = {}
      end
      targetArray[key] = value
      event.set(@target, targetArray)
    }

    # If there is a problem, set the failure tag
    if !exitstatus.nil? && exitstatus == @FAIL_PROCESSING
      @tag_on_failure.each { |tag| event.tag(tag) }
    end

    filter_matched(event)
  end

  # Create an unique hash for an event
  private
  def hashIdentifier(host, port, ldap_filter)
    md5 = Digest::MD5.new
    md5.update(host)
    md5.update(port.to_s)
    md5.update(ldap_filter)
    return md5.hexdigest
  end

  # Search LDAP attributes of the object
  private
  def ldapsearch(filter_string)
    @logger.debug? && @logger.debug("Search for LDAP '#{filter_string}'")
    exitstatus = @SUCCESS
    ret = {}

    full_filter = Net::LDAP::Filter.construct(filter_string)

    # Launch the request
    matches = 0

    begin
      @ldap.search( :base => @base_dn, :filter => full_filter, :attributes => @attributes) do |entry|
        matches += 1
        if !@match_first.nil? && matches > @match_first
          break
        end
        entry.each do |attribute, values|
          if @attributes_uppercase.include?(attribute.upcase.to_s) or @search_all_attributes
            if ret[attribute].nil?
              ret[attribute] = values
            else
              ret[attribute] = ret[attribute].concat(values)
            end
          end
        end
      end

      if @ldap.get_operation_result.code != 0
        raise(@ldap.get_operation_result.error_message)
      end
    rescue Exception => err
      @logger.error("Error while performing ldap search: #{err.message}")
      @include_error_message && ret["error"] = err.message
      exitstatus  = @FAIL_PROCESSING
      return ret, exitstatus
    end

    if matches == 0
      @logger.debug? && @logger.debug("Result set empty for ldap search #{filter_string}")
      exitstatus = @NOT_FOUND
      return ret, exitstatus
    end

    # some extra parsing
    ret[:objectsid] = LDAPUtils::get_sid_strings(ret[:objectsid]) unless ret[:objectsid].nil?
    ret[:objectguid] = LDAPUtils::unpack_guids(ret[:objectguid]) unless ret[:objectguid].nil?
    if @extract_membership and !ret[:memberof].nil?
      ret[:membership] = LDAPUtils::get_cns(ret[:memberof])
    end
    return ret, exitstatus
  end
end
