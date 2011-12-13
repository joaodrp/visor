require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Cbolt
  module Registry

    # The Client API for the VISoR Registry. This class supports all image metadata manipulation
    # operations through a programmatically interface.
    #
    # After Instantiate a Client object its possible to directly interact with the registry server and its
    # database backend.
    #
    # @example Instantiating a new VISoR Registry Client:
    #   client = Visor::Registry::Client.new('0.0.0.0', 4567)
    #     => Visor::Registry::Client:0x007fb6da03fde8 @host="0.0.0.0", @port=4567, @ssl=false>

    # @example Retrieve all public images brief metadata, descending sorted by their name:
    #   client.get_images(sort: 'name', dir: 'desc')
    #     => [{:_id=>"5e47a41e-7b94-4f65-824e-28f94e15bc6a", :name=>"Ubuntu 10.04", ... }, ... ]
    #
    class Client

      DEFAULT_HOST = '0.0.0.0'
      DEFAULT_PORT = 4567

      attr_reader :host, :port, :ssl

      # Initializes a new Client object.
      #
      # @param host (DEFAULT_HOST) [String] The host address where VISoR registry server resides.
      # @param port (DEFAULT_HOST) [Fixnum] The host port where VISoR registry server resides.
      # @param ssl (false)[Object] If the connection show be made through HTTPS (SSL).
      #
      def initialize(host=nil, port=nil, ssl=false)
        @host = host || DEFAULT_HOST
        @port = port || DEFAULT_PORT
        @ssl = ssl
      end

      # Retrieves brief metadata of all public images.
      #
      # @option params ({}) [Hash] Image attributes for filtering the returned results.
      #   Besides image attributes, the following options can be passed too.
      #
      # @option opts :sort ('_id') [String] The image attribute to sort returned results.
      # @option opts :dir ('asc') [String] The direction to sort results ('asc'/'desc').
      #
      # @return [Array] All public images brief metadata.
      #
      #   [{"_id"":<_id>,
      #     "name":<name>,
      #     "architecture":<architecture>,
      #     "type":<type>,
      #     "format":<format>,
      #     "store":<type>
      #    }, ...]}
      #
      # @raise[Visor::NotFound] If there are no public images registered on the server.
      #
      def get_images(params = {})
        query = build_query(params)
        request = Net::HTTP::Get.new("/images#{query}")
        do_request(request)
      end

      # Retrieves detailed metadata of all public images.
      #
      # @option params ({}) [Hash] Image attributes for filtering the returned results.
      #   Besides image attributes, the following options can be passed too.
      #
      # @option opts :sort ('_id') [String] The image attribute to sort returned results.
      # @option opts :dir ('asc') [String] The direction to sort results ('asc'/'desc').
      #
      # @return [Array] All public images detailed metadata.
      #
      #   [{"_id":<_id>,
      #     "uri":<uri>,
      #     "name":<name>,
      #     "architecture":<architecture>,
      #     "access":<access>,
      #     "status":<status>,
      #     "size":<size>,
      #     "type":<type>,
      #     "format":<format>,
      #     "store":<type>,
      #     "updated_at":<updated_at>,
      #     "kernel":<associated kernel>,
      #     "ramdisk":<associated ramdisk>,
      #     "others":<others>
      #    }, ...]}
      #
      # @raise[Visor::NotFound] If there are no public images registered on the server.
      #
      def get_images_detail(params = {})
        query = build_query(params)
        request = Net::HTTP::Get.new("/images/detail#{query}")
        do_request(request)
      end

      # Retrieves the image metadata with the given id.
      #
      # @param id [Integer] The wanted image's _id.
      #
      # @return [Array] The requested image metadata.
      #
      # @raise [Visor::NotFound] If image not found.
      #
      def get_image(id)
        request = Net::HTTP::Get.new("/images/#{id}")
        do_request(request)
      end

      # Register a new image on the server with the given metadata and returns its metadata.
      #
      # @param meta [Hash] The image metadata.
      #
      # @raise [Visor::Invalid] If image meta validation fails.
      #
      def post_image(meta)
        request = Net::HTTP::Post.new('/images')
        request.body = prepare_body(meta)
        do_request(request)
      end

      # Updates an image record with the given metadata and returns its metadata.
      #
      # @param id [Integer] The image's _id which will be updated.
      # @param meta [Hash] The image metadata.
      #
      # @raise [Visor::Invalid] If image meta validation fails.
      # @raise [Visor::NotFound] If required image was not found.
      #
      def put_image(id, meta)
        request = Net::HTTP::Put.new("/images/#{id}")
        request.body = prepare_body(meta)
        do_request(request)
      end

      # Removes an image record based on its _id and returns its metadata.
      #
      # @param id [Integer] The image's _id which will be deleted.
      #
      # @raise [Visor::NotFound] If required image was not found.
      #
      def delete_image(id)
        request = Net::HTTP::Delete.new("/images/#{id}")
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
      # @param params [Hash] The hash with the key/value pairs to generate query from.
      #
      # @return [String] The generated query in the form of "?k=v&k1=v1".
      #
      def build_query(params)
        params.empty? ? '' : '?' + URI.encode_www_form(params)
      end

      # Fill common header keys before each request. This sets the 'User-Agent' and 'Accept'
      # headers for every request and additionally sets the 'content-type' header
      # for POST and PUT requests.
      #
      # @param request [Net::HTTPResponse] The request which will be modified in its headers.
      #
      def prepare_headers(request)
        request['User-Agent'] = 'VISoR registry server'
        request['Accept'] = 'application/json'
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
        hash.has_key?(:image) ? meta.to_json : {image: hash}.to_json
      end

      # Process requests by preparing its headers, launch them and assert or raise their response.
      #
      # @param request [Net::HTTPResponse] The request which will be launched.
      #
      # @return [String, Hash] If an error is raised, then it parses and returns its message,
      #   otherwise it properly parse and return the response body.
      #
      # @raise [Visor::NotFound] If required image was not found (on a GET, PUT or DELETE request).
      # @raise [Visor::Invalid] If image meta validation fails (on a POST or PUT request).
      #
      def do_request(request)
        prepare_headers(request)
        response = http_or_https.request(request)
        case response
          when Net::HTTPNotFound then raise Cbolt::NotFound, parse(:message, response)
          when Net::HTTPBadRequest then raise Cbolt::Invalid, parse(:message, response)
          else parse(:image, response) or parse(:images, response)
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
