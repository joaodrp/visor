require 'time'

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
      def push_meta_into_headers(meta, headers = {})
        meta.each { |k, v| headers["x-image-meta-#{k.to_s.downcase}"] = v.to_s }
        headers
      end

      def pull_meta_from_headers(headers)
        meta = {}
        headers.each do |k, v|
          if key = k.split(/x[_-]image[_-]meta[_-]/i)[1]
            value     = parse_value v
            meta[key.downcase.to_sym] = value
          end
        end
        meta
      end

      def parse_value(string)
        if is_integer?(string) then
          Integer(string)
        elsif is_float?(string) then
          Float(object)
        elsif is_date?(string) then
          Time.parse(string)
        else
          string
        end
      end

      def is_a_meta_header?(object)

      end

      def is_integer?(object)
        true if Integer(object) rescue false
      end

      def is_float?(object)
        true if Float(object) rescue false
      end

      def is_date?(object)
        true if Time.parse(object) rescue false
      end

    end
  end
end
