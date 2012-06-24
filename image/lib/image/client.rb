require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Visor
  module Image

    # The programming API for the VISOR Image System (VIS). This class supports all image metadata and
    # files operations through a programming interface.
    #
    # After Instantiate a VIS Client object, its possible to directly interact with the VIS server. This API conforms
    # to the tenets of the VIS server REST API {Visor::Image::Server Visor Image System server}.
    #
    # @note In the examples presented in this page, we will consider that the VIS server is listening in the 10.0.0.1 address and port 4568. We will also use a sample user account, with access_key "foo" and secret_key "bar".
    #
    class Client
      include Visor::Common::Exception
      include Visor::Common::Util

      attr_reader :host, :port, :access_key, :secret_key

      # Initializes a new VIS programming client. VIS server settings (host and port address) and user's
      # credentials should be provided for initialization or ignored (where settings will be loaded from the local VISOR configuration file).
      #
      # @option opts [String] :host The host address where the VIS server resides.
      # @option opts [String] :port The host port where the VIS server listens.
      # @option opts [String] :access_key The user access key.
      # @option opts [String] :secret_key The user secret key.
      #
      # @example Instantiate a client with default values loaded from the VISOR configuration file:
      #   client = Visor::Image::Client.new
      #
      # @example Instantiate a client with custom host and port and with user's credentials loaded from the VISOR configuration file:
      #   client = Visor::Image::Client.new(host: '10.0.0.1', port: 4568)
      #
      # @example Instantiate a client with custom host, port and user's credentials (nothing is loaded from the VISOR configuration file):
      #   client = Visor::Image::Client.new(host: '10.0.0.1', port: 4568, access_key: 'foo', secret_key: 'bar')
      #
      # @return [Visor::Image::Client] A VIS programming client object.
      #
      def initialize(opts = {})
        configs     = Common::Config.load_config :visor_image
        @host       = opts[:host] || configs[:bind_host] || '0.0.0.0'
        @port       = opts[:port] || configs[:bind_port] || 4568
        @access_key = opts[:access_key] || configs[:access_key]
        @secret_key = opts[:secret_key] || configs[:secret_key]
      end

      # Retrieves detailed image metadata of the image with the given id.
      #
      # @param id [String] The wanted image's _id.
      #
      # @example Retrieve the image metadata with _id value:
      #   # wanted image _id
      #   id = "5e47a41e-7b94-4f65-824e-28f94e15bc6a"
      #
      #   # ask for that image metadata
      #   client.head_image(id)
      #
      #     # return example:
      #     {
      #        :_id          => "edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :uri          => "http://10.0.0.1:4568/images/edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :name         => "Ubuntu 12.04 Server",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => "732213248",
      #        :store        => "s3",
      #        :location     => "s3://mys3accesskey:mys3secretkey@s3.amazonaws.com/mybucket/edfa919a-0415-4d26-b54d-ae78ffc4dc79.iso",
      #        :created_at   => "2012-06-15 21:05:20 +0100",
      #        :checksum     => "140f3-2ba4b000-4be8328106940",
      #        :owner        => "foo"
      #     }
      #
      # @return [Hash] The requested image metadata.
      #
      # @raise [NotFound] If image not found.
      # @raise [Forbidden] If user authentication fails.
      # @raise [InternalError] If VIS server was not found on the referenced host and port address.
      #
      def head_image(id)
        path = "/images/#{id}"
        req  = Net::HTTP::Head.new(path)
        res  = do_request(req, false)
        pull_meta_from_headers(res)
      end

      # Retrieves brief metadata of all public and user's private images.
      # Options for filtering the returned results can be passed in.
      #
      # @option query [String] :attribute The image attribute value to filter returned results.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @example Retrieve all images brief metadata:
      #   client.get_images
      #
      #     # returns:
      #     [<all images brief metadata>]
      #
      # @example Retrieve all 32bit images brief metadata:
      #   client.get_images(architecture: 'i386')
      #
      #     # returns something like:
      #     [
      #       {:_id => "28f94e15...", :architecture => "i386", :name => "Fedora 16"},
      #       {:_id => "8cb55bb6...", :architecture => "i386", :name => "Ubuntu 11.10 Desktop"}
      #     ]
      #
      # @example Retrieve all 64bit images brief metadata, descending sorted by their name:
      #   client.get_images(architecture: 'x86_64', sort: 'name', dir: 'desc')
      #
      #     # returns something like:
      #     [
      #       {:_id => "5e47a41e...", :architecture => "x86_64", :name => "Ubuntu 10.04 Server"},
      #       {:_id => "069320f0...", :architecture => "x86_64", :name => "CentOS 6"}
      #     ]
      #
      # @return [Array] All images brief metadata.
      #   Just {Visor::Meta::Backends::Base::BRIEF BRIEF} fields are returned.
      #
      # @raise [NotFound] If there are no images registered on VISOR.
      # @raise [Forbidden] If user authentication fails.
      # @raise [InternalError] If VIS server was not found on the referenced host and port address.
      #
      def get_images(query = {})
        str = build_query(query)
        req = Net::HTTP::Get.new("/images#{str}")
        do_request(req)
      end

      # Retrieves detailed metadata of all public and user's private images.
      #
      # @note Filtering and querying works the same as with {#get_images}. The only difference is the number
      # of disclosed attributes.
      #
      # @option query [String] :attribute_name The image attribute value to filter returned results.
      # @option query [String] :sort ("_id") The image attribute to sort returned results.
      # @option query [String] :dir ("asc") The direction to sort results ("asc"/"desc").
      #
      # @example Retrieve all images detailed metadata:
      #   # request for it
      #   client.get_images_detail
      #   # returns an array of hashes with all images detailed metadata.
      #
      # @return [Array] All images detailed metadata.
      #   The {Visor::Meta::Backends::Base::DETAIL_EXC DETAIL_EXC} fields are excluded from results.
      #
      # @raise [NotFound] If there are no images registered on VISOR.
      # @raise [Forbidden] If user authentication fails.
      # @raise [InternalError] If VIS server was not found on the referenced host and port address.
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
      #
      #   # ask for that image file
      #   client.get_image(id) do |chunk|
      #     # do something with chunks as they arrive here (e.g. write to file, etc)
      #   end
      #
      # @return [Binary] The requested image file binary data.
      #
      # @raise [NotFound] If image not found.
      # @raise [Forbidden] If user authentication fails.
      # @raise [InternalError] If VIS server was not found on the referenced host and port address.
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

      # Register a new image on VISOR with the given metadata and optionally
      # upload its file, or provide a :location parameter containing the full path to
      # the already existing image file, stored somewhere.
      #
      # The image file is streamed to the server in chunks, which in turn also buffers chunks
      # as they arrive, avoiding buffering large files in memory in both clients and server.
      #
      # @note If the :location parameter is passed, you can not pass an image file
      #   and the other way around too.
      #
      # @param meta [Hash] The image metadata.
      # @param file [String] The path to the image file.
      #
      # @example Insert a sample image metadata:
      #   # sample image metadata
      #   meta = {:name => 'CentOS 6.2', :architecture => 'i386', :format => 'iso', :access => 'private'}
      #
      #   # insert the new image metadata
      #   client.post_image(meta)
      #
      #     # returns:
      #     {
      #        :_id          => "7583d669-8a65-41f1-b8ae-eb34ff6b322f",
      #        :uri          => "http://10.0.0.1:4568/images/7583d669-8a65-41f1-b8ae-eb34ff6b322f",
      #        :name         => "CentOS 6.2",
      #        :architecture => "i386",
      #        :access       => "private",
      #        :status       => "locked",
      #        :format       => "iso",
      #        :created_at   => "2012-06-15 21:01:21 +0100",
      #        :owner        => "foo"
      #     }
      #
      # @example Insert a sample image metadata and provide the location of its file:
      #   # sample image pointing to the latest release of Ubuntu Server distro
      #   meta = {:name  => 'Ubuntu 12.04 Server', :architecture => 'x86_64', :format => 'iso',
      #           :store => 'http', :location => 'http://releases.ubuntu.com/12.04/ubuntu-12.04-desktop-amd64.iso'}
      #
      #   # insert the new image metadata
      #   client.post_image(meta)
      #
      #     # returns:
      #     {
      #        :_id          => "edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :uri          => "http://10.0.0.1:4568/images/edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :name         => "Ubuntu 12.04 Server",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => 732213248, # it will find the remote file size
      #        :store        => "http",
      #        :location     => "http://releases.ubuntu.com/12.04/ubuntu-12.04-desktop-amd64.iso",
      #        :created_at   => "2012-06-15 21:05:20 +0100",
      #        :checksum     => "140f3-2ba4b000-4be8328106940", # it will also find the remote file checksum or etag
      #        :owner        => "foo"
      #     }
      #
      # @example Insert a sample image metadata and upload its file:
      #   # sample image metadata
      #   meta = {:name => 'Fedora Desktop 17', :architecture => 'x86_64', :format => 'iso', :store => 'file'}
      #
      #   # sample image file path
      #   file = '~/Fedora-17-x86_64-Live-Desktop.iso'
      #
      #   # insert the new image metadata and upload file
      #   client.post_image(meta, file)
      #
      #     # returns:
      #     {
      #        :_id          => "e5fe8ea5-4704-48f1-905a-f5747cf8ba5e",
      #        :uri          => "http://10.0.0.1:4568/images/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e",
      #        :name         => "Fedora Desktop 17",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => 676331520,
      #        :store        => "file",
      #        :location     => "file:///home/foo/VMs/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.iso",
      #        :created_at   => "2012-06-15 21:03:32 +0100",
      #        :checksum     => "330dcb53f253acdf76431cecca0fefe7",
      #        :owner        => "foo"
      #     }
      #
      # @return [Hash] The already inserted image metadata.
      #
      # @raise [Invalid] If image metadata validation fails.
      # @raise [Invalid] If the location header is present no file content can be provided.
      # @raise [Invalid] If trying to post an image file to a HTTP backend.
      # @raise [Invalid] If provided store is an unsupported store backend.
      # @raise [NotFound] If no image file is found at the provided location.
      # @raise [ConflictError] If the provided image file already exists in the target backend store.
      # @raise [Forbidden] If user authentication fails.
      # @raise [InternalError] If VIS server was not found on the referenced host and port address.
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
      # upload its file, or provide a :location parameter containing the full path to
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
      # @param file [String] The path to the image file.
      #
      # @example Update a sample image metadata:
      #   # wanted image _id
      #   id = "edfa919a-0415-4d26-b54d-ae78ffc4dc79."
      #
      #   # metadata to update
      #   update = {:name => 'Ubuntu 12.04', :architecture => "i386"}
      #
      #   # update the image metadata with some new values
      #   client.put_image(id, update)
      #
      #     # returns:
      #     {
      #        :_id          => "edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :uri          => "http://10.0.0.1:4568/images/edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :name         => "Ubuntu 12.04",
      #        :architecture => "i386",
      #        :access       => "public",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => 732213248,
      #        :store        => "http",
      #        :location     => "http://releases.ubuntu.com/12.04/ubuntu-12.04-desktop-amd64.iso",
      #        :created_at   => "2012-06-15 21:05:20 +0100",
      #        :updated_at   => "2012-06-15 21:10:36 +0100",
      #        :checksum     => "140f3-2ba4b000-4be8328106940",
      #        :owner        => "foo"
      #     }
      #
      # @example Update the image metadata and provide the location of its file. In this example,
      # the image file was already stored in the local filesystem backend,
      # thus it is not needed to upload the file, but rather just register that the image file is there.
      #   # wanted image _id
      #   id = "7583d669-8a65-41f1-b8ae-eb34ff6b322f"
      #
      #   # metadata update
      #   update = {:format => 'iso', :store => 'file', :location => 'file:///Users/server/debian-6.0.4-amd64.iso'}
      #
      #   # update the image metadata with file values
      #   client.put_image(id, update)
      #
      #     # returns:
      #     {
      #        :_id          => "7583d669-8a65-41f1-b8ae-eb34ff6b322f",
      #        :uri          => "http://10.0.0.1:4568/images/7583d669-8a65-41f1-b8ae-eb34ff6b322f",
      #        :name         => "CentOS 6.2",
      #        :architecture => "i386",
      #        :access       => "private",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => 729808896,
      #        :store        => "file",
      #        :location     => "file:///home/foo/downloads/CentOS-6.2-i386-LiveCD.iso",
      #        :created_at   => "2012-06-15 21:01:21 +0100",
      #        :updated_at   => "2012-06-15 21:12:27 +0100",
      #        :checksum     => "1b8441b6f4556be61c16d9750da42b3f",
      #        :owner        => "foo"
      #     }
      #
      # @example OR update image metadata and upload its file, if it is not already in some compatible storage backend:
      #   # wanted image _id
      #   id = "7583d669-8a65-41f1-b8ae-eb34ff6b322f"
      #
      #   # metadata update
      #   update = {:format => 'iso', :store => 'file'}
      #
      #   # sample image file path
      #   file = '~/CentOS-6.2-i386-LiveCD.iso'
      #
      #   # insert the new image metadata and upload file
      #   client.put_image(id, meta, file)
      #
      #     # returns:
      #     {
      #        :_id          => "7583d669-8a65-41f1-b8ae-eb34ff6b322f",
      #        :uri          => "http://10.0.0.1:4568/images/7583d669-8a65-41f1-b8ae-eb34ff6b322f",
      #        :name         => "CentOS 6.2",
      #        :architecture => "i386",
      #        :access       => "private",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => 729808896,
      #        :store        => "file",
      #        :location     => "file:///home/foo/VMs/7583d669-8a65-41f1-b8ae-eb34ff6b322f.iso",
      #        :created_at   => "2012-06-15 21:01:21 +0100",
      #        :updated_at   => "2012-06-15 21:12:27 +0100",
      #        :checksum     => "1b8441b6f4556be61c16d9750da42b3f",
      #        :owner        => "foo"
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
      # @raise [Forbidden] If user authentication fails.
      # @raise [InternalError] If VIS server was not found on the referenced host and port address.
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
      # @example Delete an image:
      #   # wanted image _id
      #   id = "edfa919a-0415-4d26-b54d-ae78ffc4dc79"
      #
      #   # delete the image metadata and file
      #   client.delete_image(id)
      #
      #     # returns:
      #     {
      #        :_id          => "edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :uri          => "http://10.0.0.1:4568/images/edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :name         => "Ubuntu 12.04",
      #        :architecture => "i386",
      #        :access       => "public",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => 732213248,
      #        :store        => "http",
      #        :location     => "http://releases.ubuntu.com/12.04/ubuntu-12.04-desktop-amd64.iso",
      #        :created_at   => "2012-06-15 21:05:20 +0100",
      #        :updated_at   => "2012-06-15 21:10:36 +0100",
      #        :checksum     => "140f3-2ba4b000-4be8328106940",
      #        :owner        => "foo"
      #     }
      #
      # @return [Hash] The already deleted image metadata. Useful for recover on accidental delete.
      #
      # @raise [NotFound] If image meta or file were not found.
      # @raise [Forbidden] If user does not have permission to manipulate the image file.
      # @raise [Forbidden] If user authentication fails.
      # @raise [InternalError] If VIS server was not found on the referenced host and port address.
      #
      def delete_image(id)
        req = Net::HTTP::Delete.new("/images/#{id}")
        do_request(req)
      end

      # Removes images that match a specific query.
      #
      # @param query [Hash] A query to find images that should be deleted.
      #
      # @example Delete an image by queries:
      #   # we want to delete all 64-bit images:
      #   query = {architecture: 'x86_64'}
      #
      #   # delete the image metadata and file
      #   client.delete_by_query(query)
      #
      #     # returns the matched and deleted images metadata (where in this example we had only the following 64-bit images registered):
      #     [
      #       {
      #        :_id          => "e5fe8ea5-4704-48f1-905a-f5747cf8ba5e",
      #        :uri          => "http://10.0.0.1:4568/images/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e",
      #        :name         => "Fedora Desktop 17",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => 676331520,
      #        :store        => "file",
      #        :location     => "file:///home/foo/VMs/e5fe8ea5-4704-48f1-905a-f5747cf8ba5e.iso",
      #        :created_at   => "2012-06-15 21:03:32 +0100",
      #        :checksum     => "330dcb53f253acdf76431cecca0fefe7",
      #        :owner        => "foo"
      #       },
      #       {
      #        :_id          => "edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :uri          => "http://10.0.0.1:4568/images/edfa919a-0415-4d26-b54d-ae78ffc4dc79",
      #        :name         => "Ubuntu 12.04 Server",
      #        :architecture => "x86_64",
      #        :access       => "public",
      #        :status       => "available",
      #        :format       => "iso",
      #        :size         => "732213248",
      #        :store        => "s3",
      #        :location     => "s3://mys3accesskey:mys3secretkey@s3.amazonaws.com/mybucket/edfa919a-0415-4d26-b54d-ae78ffc4dc79.iso",
      #        :created_at   => "2012-06-15 21:05:20 +0100",
      #        :checksum     => "140f3-2ba4b000-4be8328106940",
      #        :owner        => "foo"
      #       }
      #     ]
      #
      # @return [Hash] The already deleted image metadata. Useful for recover on accidental delete.
      #
      # @raise [NotFound] If image meta or file were not found.
      # @raise [Forbidden] If user does not have permission to manipulate the image file.
      # @raise [Forbidden] If user authentication fails.
      # @raise [InternalError] If VIS server was not found on the referenced host and port address.
      #
      def delete_by_query(query)
        result = []
        images = get_images(query)
        images.each do |image|
          req = Net::HTTP::Delete.new("/images/#{image[:_id]}")
          result << do_request(req)
        end
        result
      end


      private

      # Prepare headers for request
      def prepare_headers(req)
        sign_request(access_key, secret_key, req.method, req.path, req)
        req['User-Agent'] = 'VISOR Image System client'
        req['Accept']     = "application/json"
      end

      # Parses the response, which is either a JSON string inside body
      # or a error message passed on headers
      def parse_response(res)
        if res.body
          result = JSON.parse(res.body, symbolize_names: true)
          result[:image] || result[:images] || result[:message]
        else
          res['x-error-message']
        end
      end

      # Build query string from hash
      def build_query(h)
        (h.nil? or h.empty?) ? '' : '?' + URI.encode_www_form(h)
      end

      # Assert response code and raise if necessary
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
        when Net::HTTPServiceUnavailable then
          raise InternalError, parse_response(res)
        end
      end

      # Process requests
      def do_request(req, parse=true)
        prepare_headers(req)
        http              = Net::HTTP.new(host, port)
        http.read_timeout = 600
        res               = http.request(req)
        assert_response(res)
        parse ? parse_response(res) : res
      end
    end
  end
end
