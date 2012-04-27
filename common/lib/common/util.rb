require 'time'
require 'openssl'
require 'base64'

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
        if is_integer?(string) then Integer(string)
        elsif is_float?(string) then Float(object)
        elsif is_date?(string) then Time.parse(string)
        else string
        end
      end

      def is_integer?(object)
        true if Integer(object) rescue false
      end

      def is_float?(object)
        true if Float(object) rescue false
      end

      def is_date?(object)
        regexp = /\d{4}[-\/]\d{1,2}[-\/]\d{1,2}\s\d{2}:\d{2}:\d{2}\s\W\d{4}/
        object.match(regexp) ? true : false
      end

      def sign_request(access_key, secret_key, method, path, headers={})
        date = {'date' => Time.now.utc.httpdate}
        headers.update(date)

        desc      = canonical_description(method, path, headers)
        signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret_key, desc)).strip
        headers.update("Authorization" => "VISOR #{access_key}:#{signature}")
      end

      def canonical_description(method, path, headers={})
        attributes = {}
        headers.each do |key, value|
          key = key.downcase
          attributes[key] = value.to_s.strip if key.match(/^x-image-meta-|^content-md5$|^content-type$|^date$/o)
        end

        attributes['content-type'] ||= ''
        attributes['content-md5']  ||= ''

        desc = "#{method}\n"
        attributes.sort { |a, b| a[0] <=> b[0] }.each do |key, value|
          desc << (key.match(/^x-image-meta-/o) ? "#{key}:#{value}\n" : "#{value}\n")
        end
        desc << path.gsub(/\?.*$/, '')
      end

    end
  end
end

#sign_request('key', 'secret', 'GET', '/users/joaodrp', {'x-image-meta-name' => 'hi'})
