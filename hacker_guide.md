### Structure

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
  cache def something_else # Supported if same strategy and signature
    return super unless a_predicate?

    # specialized calculation
  end

  def complex(arg)
    # ... calculation
  def
  cache :complex, strategy: :disable
end
```

Equivalent code:
```
class Animal
  module RactorCacheLayer
    CACHED = ... # private information of how things are cached

    # Where caching info is stored for `Animal`
    class Store
      def initialize(owner)
        @owner = owner
      end

      attr_accessor :something, :something_else

      def freeze # only called in case of deep-freezing
        @owner.class::RactorCacheLayer.deep_freeze_callback(@owner)
        super
      end
    end

    def something
      ractor_cache.something ||= super
    end

    def freeze
      ractor_cache # make sure cache store is built
      super
    end

    def self.deep_freeze_callback(instance)
      # strategy for `something` is prebuild:
      instance.something
      # same for `something_else`:
      instance.something_else
    end

    private

    def ractor_cache
      @ractor_cache ||= self.class::Store.new
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
    CACHED = ... # private array of Strategy

    # Where caching info is stored for `Ape`
    class Store < Animal::CacheLayer::Store
      attr_reader :complex

      def initialize(owner)
        @complex = {}
        super
      end
    end

    def something_else
      ractor_cache.something_else ||= super
    end

    def complex(arg)
      hash = ractor_cache.complex
      hash.fetch(arg) do
        result = super
        # strategy is disable:
        hash[arg] = result unless frozen?
        result
      end
    end

    def self.deep_freeze_callback(instance)
      # strategy for `complex` is disable
      # nothing to do
      # process any other cached data
      # and then
      super
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
```

### Class ancestors

In the "equivalent" code above, `Animal::CacheLayer` is actually an instance of `Ractor::Cache::CacheLayer`.

`Animal::CacheLayer::Store` is a subclass of `Ractor::Cache::Store`
