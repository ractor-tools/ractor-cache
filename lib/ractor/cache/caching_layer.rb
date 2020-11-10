# frozen_string_literal: true

class Ractor
  module Cache
    module CachingLayer
      def freeze
        ractor_cache # Make sure the instance variable is created beforehand
        super
      end

      private def ractor_cache
        @ractor_cache ||= self.class::Store.new(self)
      end

      class << self
        attr_reader :sublayer, :cached, :parent

        def attach(mod, sublayer)
          @sublayer = sublayer
          @cached = []
          @parent = mod
          mod.prepend self
          substore = sublayer&.const_get(:Store, false) || Cache::Store
          const_set(:Store, Class.new(substore))

          self
        end

        def cache(method, strategy:)
          strat = build_stragegy(method, strategy)
          file, line = strat.method(:compile_accessor).source_location
          module_eval(strat.compile_accessor, file, line + 2)
          @cached << strat
          self::Store.update(@cached)
        end

        def deep_freeze_callback(instance)
          @cached.each do |strategy|
            strategy.deep_freeze_callback(instance)
          end
          sublayer&.deep_freeze_callback(instance)
        end

        # @returns [Strategy]
        private def build_stragegy(method, strategy)
          im = begin
            @parent.instance_method(method)
          rescue ::NameError => e
            raise e, "#{e.message}. Method must be defined before calling `cache`", e.backtrace
          end
          Strategy.new(strategy, to_cache: im)
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
