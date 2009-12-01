require 'active_record/base'
module MemcacheObject
  class Proxy
    # It's very tempting to want to add
    # extend ActiveSupport::Memoizable
    # here and to memoize the cache_get method. However, that would actually 
    # be counter-productive in the case where this Proxy is used like this:
    # 
    # # AUTHORS = Author.get_all_authors # Replace this with the next line
    # AUTHORS = MemcacheObject::Proxy.new(LOCAL_CACHE, 'AUTHORS', 1.day){ Author.get_all_authors } ; nil
    # 
    # What will happen there is that as the PORTALS constant is not unloaded 
    # and reloaded (as it exists in global scope), the memoized value is never 
    # purged from memory. Essentially all we would have achieved is to add 
    # Memcache to the list of places we store data, along with in the app 
    # memory itself. So, we just let each lookup use Memcache.
    # 
    # To minimise these lookups make sure you always store the intermediate 
    # result from the query - that is:
    # 
    # author = AUTHORS[126] # Single Memcache query
    # author.name
    # author.id
    # 
    # This will result in 2 Memcache queries:
    # AUTHORS[126].name
    # AUTHORS[126].portal_id

    attr_reader :cache_key
  
    def initialize(cache_store, cache_key_fragment = nil, cache_timeout = nil, &blk)
      @cache = cache_store
      @proc = blk
      @expires_in = cache_timeout || 1.day

      cache_key_fragment = @proc.object_id unless cache_key_fragment
      cache_key_parts = self.class.to_s.split(/\W+/)
      cache_key_parts << cache_key_fragment 
      @cache_key = cache_key_parts.join(' ').gsub(/\W+/, '_')
    end

    def method_missing(method_id, *arguments)
      with_cache do |data|
        data.send method_id, *arguments
      end
    end

    def with_cache(&blk)
      data = cache_get()
      yield(data)
    end

    def inspect
      cache_get().inspect
    end

    def flush_cache
      @cache.delete(@cache_key)
    end

    #protected
      def cache_get
        data = @cache.fetch(@cache_key, :expires_in => @expires_in) do
          raw_data = @proc.call
          self.class.serialize(raw_data)
        end
        #RAILS_DEFAULT_LOGGER.debug{"MemcacheObject::Proxy cache_get deserializing #{data.inspect}"}
        return self.class.deserialize(data)
      end

      def self.deserialize(data)
        #RAILS_DEFAULT_LOGGER.debug{"MemcacheObject::Proxy self.deserialize deserializing #{data.inspect}"}
        if data.is_a?(Array)
          data.collect{ |item| deserialize(item) }
        elsif data.is_a?(Hash)
          Mash.new(data)
        else
          data
        end
      end

      def self.serialize(data)
        if data.is_a?(Array)
          data.collect{ |item| serialize(item) }
        elsif data.is_a?(ActiveRecord::Base)
          data.attributes
        elsif data.is_a?(Hash)
           Hash[ *data.collect{|a, b| [ serialize(a), serialize(b) ] }.flatten ]
        else
          data
        end
      end

  end
end

=begin
require 'memcache_cache_proxy'
age_ranges = MemcacheObject::Proxy.new(LOCAL_CACHE, 'AGE_RANGES'){AgeRange.find :all} ; nil
age_ranges[1]
MemcacheObject::Proxy.serialize(AgeRange.find :all)

require 'memcache_cache_proxy'
portal_cache = MemcacheObject::Proxy.serialize(PORTALS)
portals = MemcacheObject::Proxy.deserialize(portal_cache)

require 'memcache_cache_proxy'
portals = MemcacheObject::Proxy.new(LOCAL_CACHE, 'PORTALS'){ Portal.get_all_portals } ; nil
portals[126].name
=end

