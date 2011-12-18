require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Visor
  module Registry

    # The Client API for the VISoR Registry. This class supports all image metadata manipulation
    # operations through a programmatically interface.
    #
    # After Instantiate a Client object its possible to directly interact with the registry server and its
    # database backend.
    #
    class Client

      include Visor::Common::Exception

      CONF = Common::Config.load_config :registry_server

      DEFAULT_HOST = CONF[:bind_host] || '0.0.0.0'
      DEFAULT_PORT = CONF[:bind_port] || 4567

      attr_reader :host, :port, :ssl

      # Initializes a new new VISoR Registry Client.
      #
      # @option opts [String] :host (DEFAULT_HOST) The host address where VISoR registry server resides.
      # @option opts [String] :port (DEFAULT_PORT) The host port where VISoR registry server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @example Instantiate a client with default values:
      #   client = Visor::Registry::Client.new
      #
      # @example Instantiate a client with default values and SSL enabled:
      #   client = Visor::Registry::Client.new(ssl: true)
      #
      # @example Instantiate a client with custom host and port:
      #   client = Visor::Registry::Client.new(host: '127.0.0.1', port: 3000)
      #
      def initialize(opts = {})
        @host = opts[:host] || DEFAULT_HOST
        @port = opts[:port] || DEFAULT_PORT
        @ssl = opts[:ssl] || false
      end

      # Retrieves brief metadata of all public images.
      # Options for filtering the returned results can be passed in.
      #
      # @option query [String] :attribute_name The image attribute value to filter returned results.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @example Retrieve all public images brief metadata:
      #   client.get_images
      #
      #     # returns:
      #     [<all images brief metadata>]
      #
      # @example Retrieve all public 32bit images brief metadata:
      #   client.get_images(architecture: 'i386')
      #
      #     # returns something like:
      #     [{:_id=>"28f94e15...", :architecture=>"i386", :name=>"Fedora 16"},
      #      {:_id=>"8cb55bb6...", :architecture=>"i386", :name=>"Ubuntu 11.10 Desktop"}]
      #
      # @example Retrieve all public 64bit images brief metadata, descending sorted by their name:
      #   client.get_images(architecture: 'x86_64', sort: 'name', dir: 'desc')
      #
      #     # returns something like:
      #     [{:_id=>"5e47a41e...", :architecture=>"x86_64", :name=>"Ubuntu 10.04 Server"},
      #      {:_id=>"069320f0...", :architecture=>"x86_64", :name=>"CentOS 6"}]
      #
      # @return [Array] All public images brief metadata.
      #   Just {Visor::Registry::Backends::Base::BRIEF BRIEF} fields are returned.
      #
      # @raise [NotFound] If there are no public images registered on the server.
      #
      def get_images(query = {})
        str = build_query(query)
        request = Net::HTTP::Get.new("/images#{str}")
        do_request(request)
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
      # @example Retrieve all public images detailed metadata:
      #   # request for it
      #   client.get_images_detail
      #   # returns an array of hashes with all public images metadata.
      #
      # @return [Array] All public images detailed metadata.
      #   The {Visor::Registry::Backends::Base::DETAIL_EXC DETAIL_EXC} fields are excluded from results.
      #
      # @raise [NotFound] If there are no public images registered on the server.
      #
      def get_images_detail(query = {})
        str = build_query(query)
        request = Net::HTTP::Get.new("/images/detail#{str}")
        do_request(request)
      end

      # Retrieves detailed image metadata of the image with the given id.
      #
      # @param id [String] The wanted image's _id.
      #
      # @example Retrieve the image metadata with _id value:
      #   # wanted image _id
      #   id = "5e47a41e-7b94-4f65-824e-28f94e15bc6a"
      #   # ask for that image metadata
      #   client.get_image(id)
      #
      #     # returns:
      #     { :_id=>"2cceffc6-ebc5-4741-9653-745524e7ac30",
      #       :name=>"Ubuntu 10.10",
      #       :architecture=>"x86_64",
      #       :access=>"public",
      #       :uri=>"http://0.0.0.0:4567/images/2cceffc6-ebc5-4741-9653-745524e7ac30",
      #       :format=>"iso",
      #       :type=>"ramdisk",
      #       :status=>"available",
      #       :store=>"fs" }
      #
      # @return [Hash] The requested image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def get_image(id)
        request = Net::HTTP::Get.new("/images/#{id}")
        do_request(request)
      end

      # Register a new image on the server with the given metadata and returns its metadata.
      #
      # @param meta [Hash] The image metadata.
      #
      # @example Insert a sample image metadata:
      #   # sample image metadata
      #   meta = {name: 'example', architecture: 'i386', access: 'public'}
      #   # insert the new image metadata
      #   client.post_image(meta)
      #
      #     # returns:
      #     { :_id=>"2373c3e5-b302-4529-8e23-c4ffc85e7613",
      #       :name=>"example",
      #       :architecture=>"i386",
      #       :access=>"public",
      #       :uri=>"http://0.0.0.0:4567/images/2373c3e5-b302-4529-8e23-c4ffc85e7613",
      #       :status=>"locked",
      #       :created_at=>"2011-12-13 19:19:26 UTC" }
      #
      # @return [Hash] The already inserted image metadata.
      #
      # @raise [Invalid] If image meta validation fails.
      #
      def post_image(meta)
        request = Net::HTTP::Post.new('/images')
        request.body = prepare_body(meta)
        do_request(request)
      end

      # Updates an image record with the given metadata and returns its metadata.
      #
      # @param id [String] The image's _id which will be updated.
      # @param meta [Hash] The image metadata.
      #
      # @example Update a sample image metadata:
      #   # wanted image _id
      #   id = "2373c3e5-b302-4529-8e23-c4ffc85e7613"
      #   # update the image metadata with some new values
      #   client.put_image(id, name: 'update example')
      #
      #     # returns:
      #     { :_id=>"2373c3e5-b302-4529-8e23-c4ffc85e7613",
      #       :name=>"update example",
      #       :architecture=>"i386",
      #       :access=>"public",
      #       :uri=>"http://0.0.0.0:4567/images/2373c3e5-b302-4529-8e23-c4ffc85e7613",
      #       :status=>"locked",
      #       :created_at=>"2011-12-13 19:19:26 UTC",
      #       :updated_at=>"2011-12-13 19:24:37 +0000" }
      #
      # @return [Hash] The already updated image metadata.
      #
      # @raise [Invalid] If image meta validation fails.
      # @raise [NotFound] If required image was not found.
      #
      def put_image(id, meta)
        request = Net::HTTP::Put.new("/images/#{id}")
        request.body = prepare_body(meta)
        do_request(request)
      end

      # Removes an image record based on its _id and returns its metadata.
      #
      # @param id [String] The image's _id which will be deleted.
      #
      # @example Delete an image metadata:
      #   # wanted image _id
      #   id = "2373c3e5-b302-4529-8e23-c4ffc85e7613"
      #   # delete the image metadata, which returns it as it was before deletion
      #   client.delete_image(id)
      #
      # @return [Hash] The already deleted image metadata. This is useful for recover on accidental delete.
      #
      # @raise [NotFound] If required image was not found.
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
      # @param opts [Hash] The hash with the key/value pairs to generate query from.
      #
      # @return [String] The generated query in the form of "?k=v&k1=v1".
      #
      def build_query(opts)
        opts.empty? ? '' : '?' + URI.encode_www_form(opts)
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
      # @raise [NotFound] If required image was not found (on a GET, PUT or DELETE request).
      # @raise [Invalid] If image meta validation fails (on a POST or PUT request).
      #
      def do_request(request)
        prepare_headers(request)
        response = http_or_https.request(request)
        case response
          when Net::HTTPNotFound then raise NotFound, parse(:message, response)
          when Net::HTTPBadRequest then raise Invalid, parse(:message, response)
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
