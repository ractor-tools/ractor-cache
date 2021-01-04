# frozen_string_literal: true

class Ractor
  module Cache
    module CachingLayer
      use_ractor_storage = defined?(Ractor.current) && # check we are not running Backports on a Ruby that is compatible:
                           begin
                             (::ObjectSpace::WeakMap.new[Object.new.freeze] = []) # Ruby 2.6- didn't work with frozen keys
                           rescue FrozenError
                             false
                           end

      if use_ractor_storage
        private def ractor_cache
          CachingLayer.ractor_storage[self] ||= self.class::CacheStore.new
        end
      else
        def freeze
          ractor_cache # make sure cache is initialized before freezing
          super
        end

        private def ractor_cache
          @ractor_cache ||= self.class::CacheStore.new
        end
      end

      class << self
        def ractor_storage
          Ractor.current[:RactorCacheLocalStore] ||= ::ObjectSpace::WeakMap.new
        end

        attr_reader :sublayer, :cached, :parent

        def cache(method_name)
          cm = cached_method(method_name)

          file, line = cm.method(:compile_method).source_location
          module_eval(cm.compile_method, file, line + 2)
          @cached << cm
          update_store_methods(self::CacheStore)
        end

        private def update_store_methods(store)
          init = @cached.map(&:compile_initializer).join("\n")

          store.class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def initialize
              #{init}
            end

            #{@cached.last.compile_accessor}
          RUBY
        end

        # @api private
        def attach(mod, sublayer)
          @sublayer = sublayer
          @cached = []
          @parent = mod
          mod.prepend self
          substore = sublayer&.const_get(:CacheStore, false) || Cache::Store
          const_set(:CacheStore, Class.new(substore))

          self
        end

        # @returns [CachedMethod]
        private def cached_method(method_name)
          im = begin
            @parent.instance_method(method_name)
          rescue ::NameError => e
            raise e, "#{e.message}. Method must be defined before calling `cache`", e.backtrace
          end
          CachedMethod.new(im)
        end

        # Return `CachingLayer` in `mod`, creating it if need be.
        def [](mod)
          if mod.const_defined?(:RactorCacheLayer, false)
            mod::RactorCacheLayer
          else
            sublayer = mod::RactorCacheLayer if mod.const_defined?(:RactorCacheLayer, true)
            mod.const_set(:RactorCacheLayer, dup.attach(mod, sublayer))
          end
        end
      end
    end
  end
end
