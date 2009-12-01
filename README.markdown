# MemcacheObject

MemcacheObject is a Ruby on Rails plugin for easy caching of objects for use
as constants. The plugin grew out of a need at TouchLocal to have ready access
to database table contents that was of reasonable size but changed rarely. The
initial caching method for this was to instantiate a constant that contained
the result of a database query, for example:

    PORTALS = Portal.find_all_portals # Returns a hash keyed on the Portal ID
    # A portal in the context of TouchLocal is an individual location site, 
    # for example touchlondon.co.uk or touchaberdeen.com. There are >100 of 
    # these sites, and a large proportion of the broad configuration of these 
    # Portals is stored in the Database.

While this was a quick and simple solution, it was also a dirty one, as it
caused each app server instance (each Mongrel or Phusion Passenger runner) to
load its own version of this data. As we added more and more constants into
this simple memory cache, not only did it take longer and longer to spawn a
new server, but the memory footprint of each one grew quite large, limiting
the number that could be deployed per host (essentially, costing more money to
host the site as a result.)

After a time, the logical step of changing this process to use Memcache was
started, but the constraint was that it needed to be a drop-in replacement -
don't break the old code! Thus this suite of tools in this Plugin was born.

## MemcacheObject::Proxy

Basic Usage:

    # First, configure your Memcache server.
    # It should be local to the server, if not localhost.
    # This is best done in a config/initializers file
    LOCAL_CACHE = ActiveSupport::Cache::MemCacheStore.new(
      '127.0.0.1:11211', {:namespace => "local_#{RAILS_ENV}"})
    
    # It's useful to include the RAILS_ENV in the namespace, so that you can 
    # use the same Memcache server in development and test and not have them 
    # conflict.
    
    # Now you can start attaching MemcacheObject::Proxy instances to this 
    # cache instance, as such:
    AUTHORS = MemcacheObject::Proxy.new(LOCAL_CACHE, 'AUTHORS', 1.day) do
      Author.get_all_authors
    end

`AUTHORS` is now a fully-fledged proxy object. On first run, all that has
happened is that the Proxy is initialised, but no data has been loaded. If you
then access the `AUTHORS` constant, the data is initialized and returned

    >> AUTHORS.size
    [DEBUG] 091201 17:38:03 :: Cache miss: MemcacheObject_Proxy_AUTHORS ({:expires_in=>1 day})
    [DEBUG] 091201 17:38:05 :: SQL (1.0ms)  SET NAMES 'utf8'
    [DEBUG] 091201 17:38:05 :: SQL (1.8ms)  SET SQL_AUTO_IS_NULL=0
    [DEBUG] 091201 17:38:07 :: Portal Load (60.0ms)  SELECT * FROM `authors` 
    [DEBUG] 091201 17:38:07 :: Cache write (will save 120.36ms): MemcacheObject_Proxy_AUTHORS
    => 116

Subsequent calls within the expiration period (in this case, 1 day) skip the
database loading step and just retrieve the data directly from Memcache:

    >> AUTHORS.size
    [DEBUG] 091201 17:41:14 :: Cache hit: MemcacheObject_Proxy_AUTHORS ({:expires_in=>1 day})
    => 116

The Proxy class also implements `method_missing` and `inspect` so that any
calls made on the Proxy are passed through to the stored object in a way that
makes sense. `size`, in the above example, utilized this `method_missing`
implementation as the Proxy itself has no concept of size, but the data does.
In this same way, calls to `inspect` are passed to the target data. This all
goes towards making the Proxy a drop-in replacement for the direct cache
mentioned in the opening section. Additionally, as ActiveRecord objects are
passed through the `MemcacheObject::Mash` object before storage (see below),
there is additional safety in the caching while maintaining application
compatibility.

## Utility Classes and Methods

### MemcacheObject::Boolean

`MemcacheObject::Boolean` is a simple parser for inputs to determine if they
are equivalent to `TrueClass` or `FalseClass`. The basic premis of
`MemcacheObject::Boolean` is either an input is `true` under a certain set of
rules, or it is `false`. Some examples:

    >> MemcacheObject::Boolean.parse(true)
    => true
    >> MemcacheObject::Boolean.parse('true')
    => true
    >> MemcacheObject::Boolean.parse('1')
    => true
    >> MemcacheObject::Boolean.parse(1)
    => true
    >> MemcacheObject::Boolean.parse('t')
    => true
    
    >> MemcacheObject::Boolean.parse(nil)
    => false
    >> MemcacheObject::Boolean.parse(0)
    => false
    >> MemcacheObject::Boolean.parse(false)
    => false
    >> MemcacheObject::Boolean.parse('hello')
    => false
    >> MemcacheObject::Boolean.parse(11)
    => false

### MemcacheObject::Mash

`MemcacheObject::Mash` is the glue that holds this system together. As you saw
from the initial example, most of the cached data comes from ActiveRecord and
was accessed in an ActiveRecord style. To not break this was a fundamental
requirement of the new system. However, if, over the course of a deployment an
ActiveRecord class definition changed, then an in-memory marshalled
ActiveRecord object would be invalid and unrecoverable using the new class
definition.

Unlike ActiveRecord, the Ruby Hash object does not suffer this same fate. As a
built-in object, even if you change the content of a Hash and repeatedly
serialise and deserialise it, it will always come back to an Object correctly.
Realising this, the `MemcacheObject::Mash` object extends the Hash class and
add a compatibility layer so that the resulting class instance behaves like an
ActiveRecord object but is still serialised like a Hash. ActiveRecord-style
handling of booleans is supported through the use of the `Boolean` class
above.

    >> portal = MemcacheObject::Mash.new({:name => "London", :id => 100, :active => 1})
    => {:active=>1, :name=>"London", :id=>100}
    >> portal.name
    => "London"
    >> portal.id
    => 100
    >> portal.active?
    => true

### MemcacheObject::ActiveRecordExtensions

`MemcacheObject::ActiveRecordExtensions` adds the method
`ActiveRecord::Base.find_mash_by_sql`, which leverages the `Mash` object above
to return a set of data pre-converted from ActiveRecord objects to Mash
objects. It's primarily a utility function and not used in the core of this
plugin but is included for completeness and for the help of the end user.

## Author

[Dan Sketcher](http://www.dansketcher.com) for 
[TouchLocal Ltd](http://www.touchlocal.com)

## Copyright

Copyright (c) 2009 [TouchLocal Ltd](http://www.touchlocal.com)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
