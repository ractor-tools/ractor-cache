# frozen_string_literal: true

class Ractor
  module Cache
    EMPTY_CACHE = Class.new.freeze # lazy way to get a name

    module Strategy
      class Base
        attr_reader :parameters, :method_name

        def initialize(instance_method)
          @method_name = instance_method.name
          analyse_parameters(instance_method.parameters)
        end

        def compile_store_init
          init = @has_arguments ? "Hash.new { #{EMPTY_CACHE} }" : EMPTY_CACHE
          "@#{method_name} = #{init}"
        end

        private def analyse_parameters(parameters) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
          @has_positional_arguments = @has_keywords_arguments = false
          parameters.each do |type, name|
            case type
            when :req, :opt, :rest
              @has_positional_arguments = true
              @has_keywords_arguments = true if type == :rest && name == :*
            when :key, :keyrest
              @has_keywords_arguments = true
            when :nokey, :block
              # ignore
            end
            @has_arguments = @has_positional_arguments || @has_keywords_arguments
          end
        end

        private def compile_lookup
          args = [
            *('args' if @has_positional_arguments),
            *('opts' if @has_keywords_arguments),
          ]

          return if args.empty?

          "[#{args.join(', ')}]"
        end

        private def signature
          [
            *('*args' if @has_positional_arguments),
            *('**opts' if @has_keywords_arguments),
          ].join(', ')
        end
      end

      class Prebuild < Base
        def initialize(*)
          super
          raise ArgumentError, "Can not cache method #{method_name} by prebuilding because it accepts arguments" if @has_arguments
        end

        def deep_freeze_callback(instance)
          instance.__send__ method_name
        end

        def compile_accessor
          <<~RUBY
            def #{method_name}(#{signature})
              r = ractor_cache.#{method_name}
              return r unless r == EMPTY_CACHE

              ractor_cache.#{method_name} = super
            end
          RUBY
        end
      end

      class Disable < Base
        def compile_accessor
          <<~RUBY
            def #{method_name}(#{signature})
              r = ractor_cache.#{method_name}#{compile_lookup}
              return r unless r == EMPTY_CACHE

              r = super
              ractor_cache.#{method_name}#{compile_lookup} = r unless ractor_cache.frozen?
              r
            end
          RUBY
        end

        def deep_freeze_callback(instance)
          # nothing to do
        end
      end

      MAP = {
        prebuild: Prebuild,
        disable: Disable,
      }.freeze
      private_constant :MAP

      class << self
        def [](kind)
          MAP.fetch(kind)
        end

        def new(
          strategy = nil,    # => (:prebuild | :disable)?
          to_cache:          # => UnboundMethod
        )                    # => Strategy
          self[strategy || :prebuild].new(to_cache)
        rescue ArgumentError
          return new(:disable, to_cache: to_cache) if strategy == nil

          raise
        end
      end
    end
  end
end
