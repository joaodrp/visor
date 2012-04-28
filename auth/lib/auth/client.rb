require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Visor
  module Auth

    # The Client API for the VISoR Auth.
    #
    # After Instantiate a Client object its possible to directly interact with the auth server and its
    # database backend.
    #
    class Client

      include Visor::Common::Exception

      configs = Common::Config.load_config :visor_auth

      DEFAULT_HOST = configs[:bind_host] || '0.0.0.0'
      DEFAULT_PORT = configs[:bind_port] || 4566

      attr_reader :host, :port, :ssl

      def initialize(opts = {})
        @host       = opts[:host] || DEFAULT_HOST
        @port       = opts[:port] || DEFAULT_PORT
        @ssl        = opts[:ssl] || false
      end

      def get_users(query={})
        str     = build_query(query)
        request = Net::HTTP::Get.new("/users#{str}")
        do_request(request)
      end

      def get_user(access_key)
        request = Net::HTTP::Get.new("/users/#{access_key}")
        do_request(request)
      end

      def post_user(info)
        request      = Net::HTTP::Post.new('/users')
        request.body = prepare_body(info)
        do_request(request)
      end

      def put_user(access_key, info)
        request      = Net::HTTP::Put.new("/users/#{access_key}")
        request.body = prepare_body(info)
        do_request(request)
      end

      def delete_user(access_key)
        request = Net::HTTP::Delete.new("/users/#{access_key}")
        do_request(request)
      end

      private

      # Parses a response body with the JSON parser and extracts and returns a single
      # key value from it if defined, otherwise returns all the body.
      #
      # @param key (nil) [Symbol] The hash key to extract the wanted value.
      # @param response [Net::HTTPResponse] The response which contains the body to parse.
      #
      # @return [String, Hash] If key is provided and exists on the response body, them return
      #   its value, otherwise return all the body hash.
      #
      def parse(key=nil, response)
        parsed = JSON.parse(response.body, symbolize_names: true)
        key ? parsed[key] : parsed
      end

      # Generate a valid URI query string from key/value pairs of the given hash.
      #
      # @param opts [Hash] The hash with the key/value pairs to generate query from.
      #
      # @return [String] The generated query in the form of "?k=v&k1=v1".
      #
      def build_query(h)
        (h.nil? or h.empty?) ? '' : '?' + URI.encode_www_form(h)
      end

      # Fill common header keys before each request. This sets the 'User-Agent' and 'Accept'
      # headers for every request and additionally sets the 'content-type' header
      # for POST and PUT requests.
      #
      # @param request [Net::HTTPResponse] The request which will be modified in its headers.
      #
      def prepare_headers(request)
        request['User-Agent'] = 'VISoR image server'
        request['Accept']     = 'application/json'
        request['content-type'] = 'application/json' if ['POST', 'PUT'].include?(request.method)
      end

      # Generate a valid JSON request body for POST and PUT requests.
      # It generates a JSON object encapsulated inside a :image key and then returns it.
      #
      # @param hash [Hash] The hash with the key/value pairs to generate a JSON object from.
      #
      # @return [Hash] If an :image key is already present in the hash, it just returns the plain
      #   JSON object, otherwise, encapsulate the hash inside a :image key and returns it.
      #
      def prepare_body(hash)
        hash.has_key?(:user) ? hash.to_json : {user: hash}.to_json
      end

      # Process requests by preparing its headers, launch them and assert or raise their response.
      #
      # @param request [Net::HTTPResponse] The request which will be launched.
      #
      # @return [String, Hash] If an error is raised, then it parses and returns its message,
      #   otherwise it properly parse and return the response body.
      #
      # @raise [NotFound] If required image was not found (on a GET, PUT or DELETE request).
      # @raise [Invalid] If image meta validation fails (on a POST or PUT request).
      #
      def do_request(request)
        prepare_headers(request)
        response = http_or_https.request(request)
        case response
        when Net::HTTPNotFound then
          raise NotFound, parse(:message, response)
        when Net::HTTPBadRequest then
          raise Invalid, parse(:message, response)
        when Net::HTTPConflict then
          raise ConflictError, parse(:message, response)
        else
          parse(:user, response) or parse(:users, response)
        end
      end

      # Generate a new HTTP or HTTPS connection based on initialization parameters.
      #
      # @return [Net::HTTP] A HTTP or HTTPS (not done yet) connection ready to use.
      #
      def http_or_https
        if @ssl
          #TODO: ssl connection
          #https://github.com/augustl/net-http-cheat-sheet/blob/master/ssl_and_https.rb
        else
          Net::HTTP.new(@host, @port)
        end
      end

    end
  end
end
