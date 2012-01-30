require 'em-synchrony'
require 'em-synchrony/em-http'
require 'json'

module Visor
  module API

    # The API for the VISoR Meta Server. This class supports all image metadata manipulation operations.
    #
    # This is the entry-point for the VISoR API Server to communicate with the VISoR Meta Server,
    # here are processed and logged all the calls to the meta server coming from it.
    #
    class Meta
      include Visor::Common::Exception

      DEFAULT_HOST = '0.0.0.0'
      DEFAULT_PORT = 4567

      attr_reader :host, :port, :ssl

      # Initializes a new new VISoR Meta API.
      #
      # @option opts [String] :host (DEFAULT_HOST) The host address where VISoR meta server resides.
      # @option opts [String] :port (DEFAULT_PORT) The host port where VISoR meta server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      def initialize(opts = {})
        @host = opts[:host] || DEFAULT_HOST
        @port = opts[:port] || DEFAULT_PORT
        @ssl  = opts[:ssl] || false
      end

      # Retrieves brief metadata of all public images.
      # Options for filtering the returned results can be passed in.
      #
      # @option query [String] :<attribute_name> The image attribute value to filter returned results.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @return [Array] All public images brief metadata.
      #   Just {Visor::Meta::Backends::Base::BRIEF BRIEF} fields are returned.
      #
      # @raise [NotFound] If there are no public images registered on the server.
      #
      def get_images(query = {})
        http = request.get path: '/images', query: query, head: get_headers
        return_response(http)
      end

      # Retrieves detailed metadata of all public images.
      #
      # Filtering and querying works the same as with {#get_images}. The only difference is the number
      # of disclosed attributes.
      #
      # @option query [String] :attribute_name The image attribute value to filter returned results.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @return [Array] All public images detailed metadata.
      #   The {Visor::Meta::Backends::Base::DETAIL_EXC DETAIL_EXC} fields are excluded from results.
      #
      # @raise [NotFound] If there are no public images registered on the server.
      #
      def get_images_detail(query = {})
        http = request.get path: '/images/detail', query: query, head: get_headers
        return_response(http)
      end

      # Retrieves detailed image metadata of the image with the given id.
      #
      # @param id [String] The wanted image's _id.
      #
      # @return [Hash] The requested image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def get_image(id)
        http = request.get path: "/images/#{id}", head: get_headers
        return_response(http)
      end

      # Register a new image on the server with the given metadata and returns its metadata.
      #
      # @param meta [Hash] The image metadata.
      #
      # @return [Hash] The already inserted image metadata.
      #
      # @raise [Invalid] If image meta validation fails.
      #
      def post_image(meta)
        body = prepare_body(meta)
        http = request.post path: '/images', body: body, head: post_headers
        return_response(http)
      end

      # Updates an image record with the given metadata and returns its metadata.
      #
      # @param id [String] The image's _id which will be updated.
      # @param meta [Hash] The image metadata.
      #
      # @return [Hash] The already updated image metadata.
      #
      # @raise [Invalid] If image meta validation fails.
      # @raise [NotFound] If required image was not found.
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
      # @return [Hash] The already deleted image metadata. This is useful for recover on accidental delete.
      #
      # @raise [NotFound] If required image was not found.
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
      # @param request [EventMachine::HttpRequest] The request which will be launched.
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
        parsed = JSON.parse(body, symbolize_names: true)

        case status
        when 404 then raise NotFound, parsed[:message]
        when 400 then raise Invalid, parsed[:message]
        when 500 then raise InternalError, parsed[:message]
        else parsed[:image] || parsed[:images]
        end
      end

      # Generate a new HTTP or HTTPS connection based on initialization parameters.
      #
      # @return [EventMachine::HttpRequest] A HTTP or HTTPS (not done yet) connection ready to use.
      #
      def request
        if @ssl
          #TODO: ssl connection
        else
          EventMachine::HttpRequest.new("http://#{@host}:#{@port}")
        end
      end

      # Fill common header keys before each request. This sets the 'User-Agent' and 'Accept'
      # headers for every request and additionally sets the 'content-type' header
      # for POST and PUT requests.
      #
      def get_headers
        {'User-Agent' => 'VISoR API Server',
         'Accept'     => 'application/json'}
      end

      def post_headers
        {'User-Agent'   => 'VISoR API Server',
         'Accept'       => 'application/json',
         'content-type' => 'application/json'}
      end

      alias :delete_headers :get_headers
      alias :put_headers :post_headers
    end
  end
end
