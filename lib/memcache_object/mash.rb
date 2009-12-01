module MemcacheObject
  class Mash < Hash # Model-accessible Hash
    def class
      (self['_class'] || 'Mashy').constantize
    end

    def is_a?(klass)
      k = self.class
      while k
        return true if k == klass
        k = k.superclass
      end
      false
    end

    alias :kind_of :is_a?

    def initialize(hash = nil)
      super()
      self.replace(self.class.mashify(hash)) if hash
    end

    def self.mashify(hash)
      if hash.is_a?(Hash)
        Mash[ *hash.collect{|a, b| [ a, mashify(b) ] }.flatten ]
      else
        hash
      end
    end

    def id
      self.method_missing :id
    end

    def method_missing(method_id, *arguments)
      method_name = method_id.to_s
      is_assignment_op = /\=$/.match(method_name) # is there a equal sign at the end of the method?
      is_boolean_query = /\?$/.match(method_name) # is there a question mark at the end of the method?
      key = method_name.gsub(/[\?|\=]$/, '') # get rid of '?' or '=' at the end ('=' from a setter)
      key_sym = key.to_sym

      if is_assignment_op # setter
        val = arguments.first rescue nil # note that this is not part of the condition, in case it's a +nil+
        if is_boolean_query
          raise NotImplementedError
        else
          # Try assigning back to a symbol key if it exists
          if !self[key_sym].nil?
            self[key_sym] = val
          else
            self[key] = val
          end
        end
      else # getter
        val = self[key] # note that 'false' is a valid result from this call
        val = self[key_sym] if val.nil?
        if is_boolean_query
          Boolean.parse(val)
        else
          val
        end
      end
    end
  end
end

