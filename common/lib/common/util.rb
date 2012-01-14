module Visor
  module Common

    # The Util module provides a set of utility functions used along all VISoR sub-systems.
    #
    module Util
      extend self

      # Push a hash containing image metadata into an HTTP header.
      # Each key value pair is pushed as a string of the form 'x-image-meta-<key>'.
      #
      # @param meta [Hash] The image metadata
      # @param header [Hash] (nil) The HTTP headers hash
      #
      # @return [Hash] The header containing the metadata headers
      #
      def push_meta_into_headers(meta, header = {})
        meta.each do |k, v|
          header["x-image-meta-#{k.to_s.downcase}"] = v.to_s
        end
        header
      end

    end
  end
end
