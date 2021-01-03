### Structure

(Code simplified: handling of `nil` / `false` not shown for simplicity)

```ruby
using Ractor::Cache

class Animal
  cache def something
    # ... calculation
  end

  cache def something_else
    # ... other calculation
  end
end

class Mammal < Animal
end

class Ape < Mammal
  cache def something_else
    return super unless a_predicate?

    # specialized calculation
  end

  def complex(arg)
    # ... calculation
  def
  cache :complex
end
```

Equivalent code:
```
class Animal
  module RactorCacheLayer
    # Where caching info is stored for `Animal`
    class Store
      def cached_something_or_init
        @something ||= yield
      end

      # same for something_else
    end

    def something
      ractor_cache.cached_something_or_init { super }
    end

    private

    def ractor_cache
      # similar to:
      @ractor_cache ||= self.class::Store.new
      # but actually using a ractor-local WeakMap instead of an instance variable
    end
  end
  prepend CacheLayer

  def something
    # ... calculation
  end
end

class Mammal < Animal
  # Nothing special cache-wise here.
end

class Ape < Mammal
  module RactorCacheLayer
    # Where caching info is stored for `Ape`
    class Store < Animal::CacheLayer::Store
      def initilialize
        @complex_fetch = {}
      end

      def cached_complex_or_init(owner)
        @complex_fetch[owner] ||= yield
      end
    end

    def complex(arg)
      ractor_cache.cached_complex_or_init(arg) { super }
    end

    def something_else # refine again
      ractor_cache.cached_something_else_or_init { super }
    end
  end
  prepend CacheLayer

  def complex(arg)
    # ... calculation
  def
end

Ape.ancestors # =>
[ Ape::CacheLayer, # Top cache layer
  Ape,
  Mammal,
  Animal::CacheLayer, # Second cache layer
  Animal,
  Object, #...
]

m = Ape.instance_method(:something_else)
# => #<UnboundMethod: Ape::CacheLayer#something_else()>
m = m.super_method
# => #<UnboundMethod: Ape#something_else()>
m = m.super_method
# => #<UnboundMethod: Animal::CacheLayer#something_else()>
m = m.super_method
# => #<UnboundMethod: Animal#something_else()>
```
