require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Visor
  module API

    # The Client API for the VISoR API Server. This class supports all image metadata and
    # data manipulation operations through a programmatically interface.
    #
    # After Instantiate a Client object its possible to directly interact with the
    # api server and its store backends.
    #
    class Client

      include Visor::Common::Exception
      include Visor::Common::Util

      configs = Common::Config.load_config :visor_api

      DEFAULT_HOST = configs[:bind_host] || '0.0.0.0'
      DEFAULT_PORT = configs[:bind_port] || 4568
      CHUNKSIZE    = 65536

      attr_reader :host, :port, :ssl

      # Initializes a new new VISoR API Client.
      #
      # @option opts [String] :host (DEFAULT_HOST) The host address where VISoR api server resides.
      # @option opts [String] :port (DEFAULT_PORT) The host port where VISoR api server resides.
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @example Instantiate a client with default values:
      #   client = Visor::API::Client.new
      #
      # @example Instantiate a client with default values and SSL enabled:
      #   client = Visor::API::Client.new(ssl: true)
      #
      # @example Instantiate a client with custom host and port:
      #   client = Visor::API::Client.new(host: '127.0.0.1', port: 3000)
      #
      def initialize(opts = {})
        @host = opts[:host] || DEFAULT_HOST
        @port = opts[:port] || DEFAULT_PORT
        @ssl  = opts[:ssl] || false
      end

      # Retrieves detailed image metadata of the image with the given id.
      #
      # @param id [String] The wanted image's _id.
      #
      # @example Retrieve the image metadata with _id value:
      #   # wanted image _id
      #   id = "5e47a41e-7b94-4f65-824e-28f94e15bc6a"
      #   # ask for that image metadata
      #   client.head_image(id)
      #
      #     # return example:
      #     {
      #        :_id          => "2cceffc6-ebc5-4741-9653-745524e7ac30",
      #        :name         => "Ubuntu 10.10",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :uri          => "http://0.0.0.0:4567/images/2cceffc6-ebc5-4741-9653-745524e7ac30",
      #        :format       => "iso",
      #        :status       => "available",
      #        :store        => "file"
      #     }
      #
      # @return [Hash] The requested image metadata.
      #
      # @raise [NotFound] If image not found.
      # @raise [InternalError] On internal server error.
      #
      def head_image(id)
        req = Net::HTTP::Head.new("/images/#{id}")
        res = do_request(req, false)
        pull_meta_from_headers(res)
      end

      # Retrieves brief metadata of all public images.
      # Options for filtering the returned results can be passed in.
      #
      # @option query [String] :attribute The image attribute value to filter returned results.
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
      #     [
      #       {:_id => "28f94e15...", :architecture => "i386", :name => "Fedora 16"},
      #       {:_id => "8cb55bb6...", :architecture => "i386", :name => "Ubuntu 11.10 Desktop"}
      #     ]
      #
      # @example Retrieve all public 64bit images brief metadata, descending sorted by their name:
      #   client.get_images(architecture: 'x86_64', sort: 'name', dir: 'desc')
      #
      #     # returns something like:
      #     [
      #       {:_id => "5e47a41e...", :architecture => "x86_64", :name => "Ubuntu 10.04 Server"},
      #       {:_id => "069320f0...", :architecture => "x86_64", :name => "CentOS 6"}
      #     ]
      #
      # @return [Array] All public images brief metadata.
      #   Just {Visor::Meta::Backends::Base::BRIEF BRIEF} fields are returned.
      #
      # @raise [NotFound] If there are no public images registered on the server.
      # @raise [InternalError] On internal server error.
      #
      def get_images(query = {})
        str = build_query(query)
        req = Net::HTTP::Get.new("/images#{str}")
        do_request(req)
      end

      # Retrieves detailed metadata of all public images.
      #
      # @note Filtering and querying works the same as with {#get_images}. The only difference is the number
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
      #   The {Visor::Meta::Backends::Base::DETAIL_EXC DETAIL_EXC} fields are excluded from results.
      #
      # @raise [NotFound] If there are no public images registered on the server.
      # @raise [InternalError] On internal server error.
      #
      def get_images_detail(query = {})
        str = build_query(query)
        req = Net::HTTP::Get.new("/images/detail#{str}")
        do_request(req)
      end

      # Retrieves the file of the image with the given id.
      #
      # The file is yielded in streaming chunks, so its possible to receive a big file
      # without buffering it all in memory.
      #
      # @param id [String] The wanted image's _id.
      #
      # @example Retrieve the image file with _id value:
      #   # wanted image _id
      #   id = "5e47a41e-7b94-4f65-824e-28f94e15bc6a"
      #   # ask for that image file
      #   client.get_image(id) do |chunk|
      #     # do something with each chunk as they arrive here (e.g. write to file, etc)
      #   end
      #
      # @return [Binary] The requested image file binary data.
      #
      # @raise [NotFound] If image not found.
      # @raise [InternalError] On internal server error.
      #
      def get_image(id)
        req = Net::HTTP::Get.new("/images/#{id}")
        prepare_headers(req)

        Net::HTTP.start(host, port) do |http|
          http.request(req) do |res|
            assert_response(res)
            res.read_body { |chunk| yield chunk }
          end
        end
      end

      # Register a new image on the server with the given metadata and optionally
      # upload its file, or provide a `:location` parameter containing the full path to
      # the already existing image file, stored somewhere.
      #
      # The image file is streamed to the server in chunks, which in turn also buffers chunks
      # as they arrive, avoiding buffering large files in memory in both clients and server.
      #
      # @note If the `:location` parameter is passed, you can not pass an image file
      #   and the other way around.
      #
      # @param meta [Hash] The image metadata.
      # @param file [String] (nil) The path to the image file.
      #
      # @example Insert a sample image metadata:
      #   # sample image metadata
      #   meta = {name: 'example', architecture: 'i386'}
      #   # insert the new image metadata
      #   client.post_image(meta)
      #
      #     # returns:
      #     {
      #        :_id          => "d8b36b3f-e044-4a57-88fc-27b57338be10",
      #        :uri          => "http://0.0.0.0:4568/images/d8b36b3f-e044-4a57-88fc-27b57338be10",
      #        :name         => "Ubuntu 10.04 Server",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :status       => "locked",
      #        :created_at   => "2012-02-04 16:33:27 +0000"
      #     }
      #
      # @example Insert a sample image metadata and provide the location of its file:
      #   # sample image poiting to the latest release of Ubuntu Server distro
      #   meta = {:name  => 'Ubuntu Server (Latest)', :architecture => 'x86_64', :format => 'iso',
      #           :store => 'http', :location => 'http://www.ubuntu.com/start-download?distro=server&bits=64&release=latest'}
      #   # insert the new image metadata
      #   client.post_image(meta)
      #
      #     # returns:
      #     {
      #        :_id          => "0733827b-836d-469e-8860-b900d4dabc46",
      #        :uri          => "http://0.0.0.0:4568/images/0733827b-836d-469e-8860-b900d4dabc46",
      #        :name         => "Ubuntu Server (Latest)",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :format       => "iso",
      #        :store        => "http",
      #        :location     => "http://www.ubuntu.com/start-download?distro=server&bits=64&release=latest",
      #        :status       => "available",
      #        :size         => 715436032, # it will fetch the correct remote file size
      #        :created_at   => "2012-02-04 16:40:04 +0000",
      #        :updated_at   => "2012-02-04 16:40:04 +0000",
      #        :checksum     => "76264-2aa4b000-4af0618f1b180" # it will also fetch the remote file checksum or etag
      #     }
      #
      # @example Insert a sample image metadata and upload its file:
      #   # sample image metadata
      #   meta = {:name => 'Ubuntu 10.04 Server', :architecture => 'x86_64', :store => 's3', :format => 'iso'}
      #   # sample image file path
      #   file = '~/ubuntu-10.04.3-server-amd64.iso'
      #   # insert the new image metadata and upload file
      #   client.post_image(meta, file)
      #
      #     # returns:
      #     {
      #        :_id          => "8074d23e-a9c0-454d-b935-cda5f6eb1bc8",
      #        :uri          => "http://0.0.0.0:4568/images/8074d23e-a9c0-454d-b935-cda5f6eb1bc8",
      #        :name         => "Ubuntu 10.04 Server",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :format       => "iso",
      #        :store        => "file",
      #        :location     => "s3://<access_key>:<secret_key>@s3.amazonaws.com/<bucket>/8074d23e-a9c0-454d-b935-cda5f6eb1bc8.iso",
      #        :status       => "available",
      #        :size         => 713529344,
      #        :created_at   => "2012-02-04 16:29:04 +0000",
      #        :updated_at   => "2012-02-04 16:29:04 +0000",
      #        :checksum     => "fbd9044604120a1f6cc708048a21e066"
      #     }
      #
      # @return [Hash] The already inserted image metadata.
      #
      # @raise [Invalid] If image metadata validation fails.
      # @raise [Invalid] If the location header is present no file content can be provided.
      # @raise [Invalid] If trying to post an image file to a HTTP backend.
      # @raise [Invalid] If provided store is an unsupported store backend.
      # @raise [NotFound] If no image data is found at the provided location.
      # @raise [ConflictError] If the provided image file already exists in the backend store.
      # @raise [InternalError] On internal server error.
      #
      def post_image(meta, file = nil)
        req = Net::HTTP::Post.new('/images')
        push_meta_into_headers(meta, req)
        if file
          req['Content-Type']      = 'application/octet-stream'
          req['Transfer-Encoding'] = 'chunked'
          req.body_stream          = File.open(File.expand_path file)
        end
        do_request(req)
      end

      # Updates an image record with the given metadata and optionally
      # upload its file, or provide a `:location` parameter containing the full path to
      # the already existing image file, stored somewhere.
      #
      # The image file is streamed to the server in chunks, which in turn also buffers chunks
      # as they arrive, avoiding buffering large files in memory in both clients and server.
      #
      # @note Only images with status set to 'locked' or 'error' can be updated
      #   with an image data file.
      #
      # @param id [String] The image's _id which will be updated.
      # @param meta [Hash] The image metadata.
      # @param file [String] (nil) The path to the image file.
      #
      # @example Update a sample image metadata:
      #   # wanted image _id
      #   id = "2373c3e5-b302-4529-8e23-c4ffc85e7613"
      #   # metadata to update
      #   update = {:name => 'Debian 6.0', :architecture => "x86_64"}
      #   # update the image metadata with some new values
      #   client.put_image(id, update)
      #
      #     # returns:
      #     {
      #        :_id          => "2373c3e5-b302-4529-8e23-c4ffc85e7613",
      #        :uri          => "http://0.0.0.0:4568/images/2373c3e5-b302-4529-8e23-c4ffc85e7613",
      #        :name         => "Debian 6.0",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :status       => "locked",
      #        :created_at   => "2012-02-03 12:40:30 +0000"
      #        :updated_at   => "2012-02-04 16:35:10 +0000"
      #     }
      #
      # @example Update a sample image metadata and provide the location of its file:
      #   # wanted image _id
      #   id = "2373c3e5-b302-4529-8e23-c4ffc85e7613"
      #   # metadata update
      #   update = {:format => 'iso', :store => 'file', :location => 'file:///Users/server/debian-6.0.4-amd64.iso'}
      #   # update the image metadata with file values
      #   client.put_image(id, update)
      #
      #     # returns:
      #     {
      #        :_id          => "2373c3e5-b302-4529-8e23-c4ffc85e7613",
      #        :uri          => "http://0.0.0.0:4568/images/2373c3e5-b302-4529-8e23-c4ffc85e7613",
      #        :name         => "Debian 6.0",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :status       => "locked",
      #        :format       => "iso",
      #        :store        => "file",
      #        :location     => "file:///Users/server/debian-6.0.4-amd64.iso",
      #        :status       => "available",
      #        :size         => 764529654,
      #        :created_at   => "2012-02-03 12:40:30 +0000"
      #        :updated_at   => "2012-02-04 16:38:55 +0000"
      #     }
      #
      # @example Update image metadata and upload its file:
      #   # wanted image _id
      #   id = "d5bebdc8-66eb-4450-b8d1-d8127f50779d"
      #   # metadata update
      #   update = {:format => 'iso', :store => 's3'}
      #   # sample image file path
      #   file = '~/CentOS-6.2-x86_64-LiveCD.iso'
      #   # insert the new image metadata and upload file
      #   client.put_image(id, meta, file)
      #
      #     # returns:
      #     {
      #        :_id          => "d5bebdc8-66eb-4450-b8d1-d8127f50779d",
      #        :uri          => "http://0.0.0.0:4568/images/d5bebdc8-66eb-4450-b8d1-d8127f50779d",
      #        :name         => "CentOS 6.2",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :format       => "iso",
      #        :store        => "s3",
      #        :location     => "s3://<access_key>:<secret_key>@s3.amazonaws.com/<bucket>/d5bebdc8-66eb-4450-b8d1-d8127f50779d.iso",
      #        :status       => "available",
      #        :size         => 731906048,
      #        :created_at   => "2012-01-20 16:29:01 +0000",
      #        :updated_at   => "2012-02-04 16:50:12 +0000",
      #        :checksum     => "610c0b9684dba804467514847e8a012f"
      #     }
      #
      # @return [Hash] The already inserted image metadata.
      #
      # @raise [Invalid] If the image metadata validation fails.
      # @raise [Invalid] If no headers neither body found for update.
      # @raise [Invalid] If the location header is present no file content can be provided.
      # @raise [Invalid] If trying to post an image file to a HTTP backend.
      # @raise [Invalid] If provided store is an unsupported store backend.
      # @raise [NotFound] If no image data is found at the provided location.
      # @raise [ConflictError] If trying to assign image file to a locked or uploading image.
      # @raise [ConflictError] If the provided image file already exists in the backend store.
      # @raise [InternalError] On internal server error.
      #
      def put_image(id, meta, file = nil)
        req = Net::HTTP::Put.new("/images/#{id}")
        push_meta_into_headers(meta, req) if meta
        if file
          req['Content-Type']      = 'application/octet-stream'
          req['Transfer-Encoding'] = 'chunked'
          req.body_stream          = File.open(File.expand_path file)
        end
        do_request(req)
      end

      # Removes an image record based on its _id and returns its metadata. If the image
      # have some registered image file, that file is also deleted on its source store.
      #
      # @param id [String] The image's _id which will be deleted.
      #
      # @example Delete an image metadata:
      #   # wanted image _id
      #   id = "66414330-bbb5-42be-8a0e-b336cf6665f4"
      #   # delete the image metadata and file
      #   client.delete_image(id)
      #
      #     # returns:
      #     {
      #        :_id          => "66414330-bbb5-42be-8a0e-b336cf6665f4",
      #        :uri          => "http://0.0.0.0:4568/images/66414330-bbb5-42be-8a0e-b336cf6665f4",
      #        :name         => "Ubuntu 11.04 Server",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :format       => "iso",
      #        :store        => "file",
      #        :location     => "file:///Users/server/VMs/66414330-bbb5-42be-8a0e-b336cf6665f4.iso",
      #        :status       => "available",
      #        :size         => 722549344,
      #        :created_at   => "2012-02-04 15:23:48 +0000",
      #        :updated_at   => "2012-02-04 15:54:52 +0000",
      #        :accessed_at  => "2012-02-04 16:02:44 +0000",
      #        :access_count => 26,
      #        :checksum     => "fbd9044604120a1f6cc708048a21e066"
      #     }
      #
      # @return [Hash] The already deleted image metadata. Useful for recover on accidental delete.
      #
      # @raise [NotFound] If image meta or data not found.
      # @raise [Forbidden] If user does not have permission to manipulate the image file.
      # @raise [InternalError] On internal server error.
      #
      def delete_image(id)
        req = Net::HTTP::Delete.new("/images/#{id}")
        do_request(req)
      end

      private

      def prepare_headers(req)
        req['User-Agent'] = 'VISoR API Server client'
        req['Accept']     = "application/json"
      end

      def parse_response(res)
        if res.body
          result = JSON.parse(res.body, symbolize_names: true)
          result[:image] || result[:images] || result[:message]
        else
          res['x-error-message']
        end
      end

      def build_query(h)
        h.empty? ? '' : '?' + URI.encode_www_form(h)
      end

      def assert_response(res)
        case res
        when Net::HTTPNotFound then
          raise NotFound, parse_response(res)
        when Net::HTTPBadRequest then
          raise Invalid, parse_response(res)
        when Net::HTTPConflict then
          raise ConflictError, parse_response(res)
        when Net::HTTPForbidden then
          raise Forbidden, parse_response(res)
        when Net::HTTPInternalServerError then
          raise InternalError, parse_response(res)
        end
      end

      def do_request(req, parse=true)
        prepare_headers(req)
        res = Net::HTTP.new(host, port).request(req)
        assert_response(res)
        parse ? parse_response(res) : res
      end

    end
  end
end
