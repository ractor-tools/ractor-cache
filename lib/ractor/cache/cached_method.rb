# frozen_string_literal: true
# shareable_constant_values: literal

class Ractor
  module Cache
    module CachedMethod
      Base = Struct.new(:method_name, :argument_kind)
      class Base
        def compile_method
          <<~RUBY
            def #{method_name}#{args}
              ractor_cache.cached_#{method_name}_or_init#{args} { super }
            end
          RUBY
        end

        SIGNATURES = {
          none:       [''],
          positional: ['(*args)',        'args'],
          keyword:    ['(**opt)',        'opt'],
          both:       ['(*args, **opt)', '[args, opt]'],
        }
        private_constant :SIGNATURES

        private def args
          SIGNATURES.fetch(argument_kind).first
        end

        private def key
          SIGNATURES.fetch(argument_kind).fetch(1)
        end
      end

      class WithoutArgument < Base
        def compile_initializer
          ''
        end

        def compile_accessor
          <<~RUBY
            def cached_#{method_name}_or_init
              return @#{method_name} if defined?(@#{method_name})

              @#{method_name} = yield
            end
          RUBY
        end
      end

      class WithArguments < Base
        def compile_initializer
          "@#{method_name} = {}"
        end

        def compile_accessor
          <<~RUBY
            def cached_#{method_name}_or_init#{args}
              @#{method_name}.fetch(#{key}) do
                @#{method_name}[#{key}] = yield
              end
            end
          RUBY
        end
      end

      class << self
        def new(instance_method)
          kind = argument_kind(instance_method.parameters)
          klass = kind == :none ? WithoutArgument : WithArguments
          klass.new(instance_method.name, kind)
        end

        private def argument_kind(parameters) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
          kind = :none
          parameters.each do |type, name|
            case type
            when :req, :opt, :rest
              return :both if type == :rest && name == :*

              kind = :positional
            when :key, :keyrest
              return kind == :positional ? :both : :keyword
            when :nokey, :block
              # ignore
            end
          end
          kind
        end
      end
    end
  end
end
