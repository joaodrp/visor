require 'em-synchrony'
require 'em-synchrony/em-http'
require 'json'

module Visor
  module Image

    # The API for the VISOR Meta System (VMS) server. This class supports all image metadata manipulation operations.
    #
    # This is the API used by the VISOR Image System (VIS) to communicate with the VMS in order to accomplish
    # metadata retrieving and registering operations.
    #
    class Meta
      include Visor::Common::Exception

      attr_reader :host, :port

      # Initializes a new new VMS interface.
      #
      # @option opts [String] :host The host address where VMS server resides.
      # @option opts [String] :port The host port where VMS server listens.
      #
      def initialize(opts = {})
        @host = opts[:host]
        @port = opts[:port]
      end

      # Retrieves all public and user’s private images brief metadata.
      # Options for filtering the returned results can be passed in.
      #
      # @option query [String] :<attribute_name> The image attribute value to filter returned results.
      # @param owner (nil) [String] The user's access key to look for its private images too.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @return [Array] All images brief metadata.
      #   Just {Visor::Meta::Backends::Base::BRIEF BRIEF} attributes are returned.
      #
      # @raise [NotFound] If there are no images registered on VMS.
      #
      def get_images(query = {}, owner=nil)
        query.merge!(owner: owner) if owner
        http = request.get path: '/images', query: query, head: get_headers
        return_response(http)
      end

      # Retrieves all public and user’s private images detailed metadata.
      #
      # Filtering and querying works the same as with {#get_images}. The only difference is the number
      # of disclosed attributes.
      #
      # @option query [String] :attribute_name The image attribute value to filter returned results.
      # @param owner (nil) [String] The user's access_key to look for its private images too.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @return [Array] All public images detailed metadata.
      #   The {Visor::Meta::Backends::Base::DETAIL_EXC DETAIL_EXC} fields are excluded from results.
      #
      # @raise [NotFound] If there are no images registered on the server.
      #
      def get_images_detail(query = {}, owner=nil)
        query.merge!(owner: owner) if owner
        http = request.get path: '/images/detail', query: query, head: get_headers
        return_response(http)
      end

      # Retrieves detailed metadata of the image with the given id.
      #
      # @param id [String] The wanted image's _id.
      #
      # @return [Hash] The requested image detailed metadata.
      #
      # @raise [NotFound] If image metadata was not found.
      #
      def get_image(id)
        http = request.get path: "/images/#{id}", head: get_headers
        return_response(http)
      end

      # Register a new image metadata on VMS and return it.
      #
      # @param meta [Hash] The image metadata.
      #
      # @return [Hash] The already inserted detailed image metadata.
      #
      # @raise [Invalid] If image metadata validation fails.
      #
      def post_image(meta, address)
        body = prepare_body(meta)
        http = request.post path: '/images', body: body, head: post_headers(address)
        return_response(http)
      end

      # Updates an image metadata with the given metadata and returns it.
      #
      # @param id [String] The image's _id which will be updated.
      # @param meta [Hash] The image metadata.
      #
      # @return [Hash] The already updated detailed image metadata.
      #
      # @raise [Invalid] If image meta validation fails.
      # @raise [NotFound] If the target image metadata was not found.
      #
      def put_image(id, meta)
        body = prepare_body(meta)
        http = request.put path: "/images/#{id}", body: body, head: put_headers
        return_response(http)
      end

      # Removes an image record based on its _id and returns its metadata.
      #
      # @param id [String] The image's _id which will be deleted.
      #
      # @return [Hash] The already deleted detailed image metadata. This is useful for recovery on accidental delete.
      #
      # @raise [NotFound] If the target image metadata was not found.
      #
      def delete_image(id)
        http = request.delete path: "/images/#{id}", head: delete_headers
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
        hash.has_key?(:image) ? meta.to_json : {image: hash}.to_json
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
          raise InternalError, "VISOR Meta System server not found. Is it running?"
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
        parsed[:image] || parsed[:images] || parsed[:message]
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

      def put_headers
        {'User-Agent'   => "VISOR Image System",
         'Accept'       => 'application/json',
         'content-type' => 'application/json'}
      end

      def post_headers(address)
        {'User-Agent'   => "VISOR Image System - #{address}",
         'Accept'       => 'application/json',
         'content-type' => 'application/json'}
      end

      alias :delete_headers :get_headers
    end
  end
end
