# frozen_string_literal: true

class Ractor
  module Cache
    class Store
      def initialize(owner) # Possibly redefined by `update`
        @owner = owner
      end

      def freeze
        @owner.class::RactorCacheLayer.deep_freeze_callback(@owner)
        super
      end

      class << self
        def update(cached)
          update_accessors(cached)
          update_init(cached)
        end

        private def update_accessors(cached)
          attr_accessor(*cached.map(&:method_name))
        end

        private def update_init(cached)
          body = cached.map(&:compile_store_init).join("\n")
          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def initialize(owner)
              #{body}
              super
            end
          RUBY
        end
      end
    end
  end
end
