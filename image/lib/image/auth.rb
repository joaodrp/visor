require 'em-synchrony'
require 'em-synchrony/em-http'
require 'uri'
require 'json'

module Visor
  module Image

    # The API for the VISOR Auth System (VAS) server. This class supports all user's manipulation operations.
    #
    # After Instantiate a VAS API client object its possible to directly interact with the VAS server and its
    # database backend.
    #
    class Auth
      include Visor::Common::Exception

      attr_reader :host, :port

      def initialize(opts = {})
        @host = opts[:host]
        @port = opts[:port]
      end

      # Get information about all registered users.
      #
      # Options for filtering the returned results can be passed in.
      #
      # @option query [String] :<attribute_name> The user attribute value to filter returned results.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @return [Array] All user's accounts.
      #
      # @raise [NotFound] If there are no users registered on VAS.
      #
      def get_users(query = {})
        http = request.get path: '/users', query: query, head: get_headers
        return_response(http)
      end

      # Get information about a specific user.
      #
      # @param access_key [String] The user access key (username).
      #
      # @return [Hash] The requested user account information.
      #
      # @raise [NotFound] If user was not found.
      #
      def get_user(access_key)
        http = request.get path: "/users/#{access_key}", head: get_headers
        return_response(http)
      end

      # Register a new user account on VAS and return its data.
      #
      # @param info [Hash] The user information.
      #
      # @return [Hash] The already created user detailed information.
      #
      # @raise [Invalid] If user data validation fails.
      # @raise [NotFound] If user was not found after registered.
      # @raise [ConflictError] access_key was already taken.
      #
      def post_user(info)
        body = prepare_body(info)
        http = request.post path: '/users', body: body, head: post_headers
        return_response(http)
      end

      # Update an existing user information and return it.
      #
      # @param access_key [String] The wanted user access_key.
      # @param info [Hash] The user information.
      #
      # @return [Hash] The already updated user detailed information.
      #
      # @raise [Invalid] If user data validation fails.
      # @raise [NotFound] If user was not found.
      #
      def put_user(access_key, info)
        body = prepare_body(info)
        http = request.put path: "/users/#{access_key}", body: body, head: put_headers
        return_response(http)
      end

      # Delete an user and returns its information.
      #
      # @param access_key [String] The wanted user access_key.
      #
      # @return [Hash] The already deleted user detailed information.
      #
      # @raise [NotFound] If user was not found.
      #
      def delete_user(access_key)
        http = request.delete path: "/users/#{access_key}", access_key: delete_headers
        return_response(http)
      end

      private

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
      # @param http [EventMachine::HttpRequest] The request which will be launched.
      #
      # @return [String, Hash] If an error is raised, then it parses and returns its message,
      #   otherwise it properly parse and return the response body.
      #
      # @raise [NotFound] If required image was not found (on a GET, PUT or DELETE request).
      # @raise [Invalid] If image meta validation fails (on a POST or PUT request).
      #
      def return_response(http)
        body   = http.response
        status = http.response_header.status.to_i

        case status
        when 0 then
          raise InternalError, "VISOR Auth System server not found. Is it running?"
        when 404 then
          raise NotFound, parse(body)
        when 400 then
          raise Invalid, parse(body)
        when 500 then
          raise InternalError, parse(body)
        else
          parse(body)
        end
      end

      def parse(body)
        parsed = JSON.parse(body, symbolize_names: true)
        parsed[:user] || parsed[:users] || parsed[:message]
      end

      # Generate a new HTTP or HTTPS connection based on initialization parameters.
      #
      # @return [EventMachine::HttpRequest] A HTTP or HTTPS (not done yet) connection ready to use.
      #
      def request
        #if @ssl
          #TODO: ssl connection
        #else
          EventMachine::HttpRequest.new("http://#{@host}:#{@port}")
        #end
      end

      # Fill common header keys before each request. This sets the 'User-Agent' and 'Accept'
      # headers for every request and additionally sets the 'content-type' header
      # for POST and PUT requests.
      #
      def get_headers
        {'User-Agent' => 'VISOR Image System',
         'Accept'     => 'application/json'}
      end

      def post_headers
        {'User-Agent'   => 'VISOR Image System',
         'Accept'       => 'application/json',
         'content-type' => 'application/json'}
      end

      alias :delete_headers :get_headers
      alias :put_headers :post_headers
    end
  end
end

