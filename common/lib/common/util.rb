require 'time'
require 'openssl'
require 'base64'

module Visor
  module Common

    # The Util module provides a set of utility functions used along all VISOR subsystems.
    #
    module Util
      extend self

      # Push a hash containing image metadata into an HTTP header.
      # Each key value pair is pushed as a string of the form 'x-image-meta-<key>'.
      #
      # @param meta [Hash] The image metadata
      # @param headers [Hash] (nil) The HTTP headers hash
      #
      # @return [Hash] The header containing the metadata headers
      #
      def push_meta_into_headers(meta, headers = {})
        meta.each { |k, v| headers["x-image-meta-#{k.to_s.downcase}"] = v.to_s }
        headers
      end

      # Pull image metadata from HTTP headers to a hash.
      #
      # @param headers [Hash] (nil) The HTTP headers hash
      #
      # @return [Hash] The header containing the metadata
      #
      def pull_meta_from_headers(headers)
        meta = {}
        headers.each do |k, v|
          if key = k.split(/x[_-]image[_-]meta[_-]/i)[1]
            value                     = parse_value v
            meta[key.downcase.to_sym] = value
          end
        end
        meta
      end

      # Find if a string value is an integer, a float or a date. If it matches a type,
      # then it is converted to that type and returned.
      #
      # @param string [String] The string to be parsed.
      #
      # @return [Object] The already converted string value.
      #
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

      # Find if a an object can be converted to an integer.
      #
      # @param object [Object] The object to be converted to integer.
      #
      # @return [Integer,NilClass] The converted integer, or nil if it can not be converted to integer.
      #
      def is_integer?(object)
        true if Integer(object) rescue false
      end

      # Find if a an object can be converted to a float.
      #
      # @param object [Object] The object to be converted to a float.
      #
      # @return [Float,NilClass] The converted float, or nil if it can not be converted to a float.
      #
      def is_float?(object)
        true if Float(object) rescue false
      end

      # Find if a an object can be converted to a date.
      #
      # @param object [Object] The object to be converted to a date.
      #
      # @return [Date,NilClass] The converted float, or nil if it can not be converted to a date.
      #
      def is_date?(object)
        regexp = /\d{4}[-\/]\d{1,2}[-\/]\d{1,2}\s\d{2}:\d{2}:\d{2}\s\W\d{4}/
        object.match(regexp) ? true : false
      end

      # Sign a request by generating an authorization string and embedding it in the request headers.
      #
      # @param access_key [String] The requester user access key.
      # @param secret_key [String] The requester user secret key.
      # @param method [String] The request method.
      # @param path [String] The request path.
      # @param headers [Hash] The request headers.
      #
      def sign_request(access_key, secret_key, method, path, headers={})
        headers['Date'] ||= Time.now.utc.httpdate
        desc            = canonical_description(method, path, headers)
        signature       = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret_key, desc)).strip

        headers['Authorization'] = "VISOR #{access_key}:#{signature}"
      end

      # Generate a request canonical description, which will be used by {#sign_request}.
      #
      # @param method [String] The request method.
      # @param path [String] The request path.
      # @param headers [Hash] The request headers.
      #
      # @return [String] The request canonical description string.
      #
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

      # Authenticate an user request by analysing the request authorization string.
      #
      # @param env [Hash] The request attributes.
      # @param vas [Visor::Image::Auth] A VAS interface object, used to query for user credentials.
      #
      # @return [String] The authenticated user access key.
      #
      # @raise [Forbidden] If authorization header was not provided along the request.
      # @raise [Forbidden] If no access key found in the authorization header string.
      # @raise [Forbidden] If no user found with the given access key.
      # @raise [Forbidden] If signatures do not match.
      # @raise [InternalError] If VAS server was not found.
      #
      def authorize(env, vas)
        auth = env['headers']['Authorization']
        raise Visor::Common::Exception::Forbidden, "Authorization not provided." unless auth
        access_key = auth.scan(/\ (\w+):/).flatten.first
        raise Visor::Common::Exception::Forbidden, "No access key found in Authorization." unless access_key
        begin
          user = vas.get_user(access_key)
        rescue Visor::Common::Exception::InternalError => e
          raise Visor::Common::Exception::InternalError, e.message
        rescue => e
          nil
        end
        raise Visor::Common::Exception::Forbidden, "No user found with access key '#{access_key}'." unless user
        sign = sign_request(user[:access_key], user[:secret_key], env['REQUEST_METHOD'], env['REQUEST_PATH'], env['headers'])
        raise Visor::Common::Exception::Forbidden, "Invalid authorization, signatures do not match." unless auth == sign
        access_key
      end

    end
  end
end
