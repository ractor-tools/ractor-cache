# frozen_string_literal: true

using Ractor::Cache

class Base
  def calls
    self.class.registry[self]
  end

  def record(*args)
    name = caller_locations(1, 1).first.label
    value = args.empty? ? name.to_sym : [name.to_sym, *args]
    (calls << value).dup
  end

  def self.registry
    @registry ||= Hash.new { |h, k| h[k] = [] }.compare_by_identity
  end
end

class Animal < Base
  cache def something
    record
  end

  cache def something_else
    record
  end
end

class Mammal < Animal
end

class Ape < Mammal
  cache def something_else # Supported if same strategy and signature
    super
    record(:refined)
  end

  def complex(arg)
    record(arg)
  end
  cache :complex
end

class Nihilist < Base
  cache def simple
    record
    nil
  end

  cache def complex(_arg)
    record
    nil
  end
end
