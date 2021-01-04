# frozen_string_literal: true

require 'require_relative_dir'
using RequireRelativeDir

class Ractor
  module Cache
    require_relative_dir

    CacheStore = ::Hash # By default, use a Hash
    include CachingLayer

    refine Module do
      def cache(method_name)
        CachingLayer[self].cache(method_name)
      end
    end
  end
end
