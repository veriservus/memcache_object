require 'active_record/base'

module MemcacheObject
  module ActiveRecordExtensions
    # Works like find(:all), but requires a complete SQL string. Examples:
    #   Post.find_by_sql "SELECT p.*, c.author FROM posts p, comments c WHERE p.id = c.post_id"
    #   Post.find_by_sql ["SELECT * FROM posts WHERE author = ? AND created > ?", author_id, start_date]
    def self.find_mash_by_sql(sql) # Model-accessible Hash
      connection.select_all(sanitize_sql(sql), "#{name} Load").collect! { |record| Mash.new(record) }
    end
  end
end

ActiveRecord::Base.send :extend, MemcacheObject::ActiveRecordExtensions
