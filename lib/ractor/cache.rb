# frozen_string_literal: true

require 'require_relative_dir'
using RequireRelativeDir

class Ractor
  module Cache
    require_relative_dir

    private def cache(method_name, strategy: nil)
      CachingLayer[self].cache(method_name, strategy: strategy)
    end

    refine Module do
      include Cache
    end
  end
end
