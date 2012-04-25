require 'time'
require 'openssl'
require 'base64'

module Visor
  module Common

    # The Signature module provides a set of utility functions to securely sign requests.
    #
    module Signature

      def self.sign_request(access_key, secret_key, method, path, headers={})
        date = {'date' => Time.now.utc.httpdate}
        headers.update(date)

        desc      = canonical_description(method, path, headers)
        signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret_key, desc)).strip
        headers.update("Authorization" => "AWS #{access_key}:#{signature}")
      end

      def self.canonical_description(method, path, headers={})
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

