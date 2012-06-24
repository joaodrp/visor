require 'goliath'
require 'tempfile'
require 'json'

module Visor
  module Image

    # The VISOR Image System (VIS) server. This server is the VISOR front-end and supports all image metadata manipulation
    # operations (dispatched to the VISOR Meta System) and the image files management too.
    #
    # **The Server is a RESTful Web service with the following API:**
    #
    #   HEAD    /images/<id>    - Return detailed metadata of a given image.
    #   GET     /images         - Return brief metadata of all public and user’s private images.
    #   GET     /images/detail  - Return detailed metadata of all public and user’s private images.
    #   GET     /images/<id>    - Return the metadata and file of a given image.
    #   POST    /images         - Add new metadata and optionally upload a file.
    #   PUT     /images/<id>    - Update the metadata and/or file of a given image.
    #   DELETE  /images/<id>    - Remove the metadata and file of a given image.
    #
    # The VIS API is multi-format, most properly it supports response encoding in JSON and XML formats.
    # It will auto negotiate and encode the response metadata and error messages in the proper format,
    # based on the request *Accept* header, being it 'application/json' or 'application/xml'.
    # If no Accept header is provided, Image will encode and render it as JSON by default.
    #
    # This server routes all metadata operations to the {Visor::Meta::Server Visor Meta System server}.
    #
    # The server will interact with the multiple supported backend store to manage the image files.
    #
    # **Currently we support the following store backend and operations:**
    #
    #   Amazon Simple Storage (s3)  - GET, POST, PUT, DELETE
    #   Lunacloud Storage (lcs)     - GET, POST, PUT, DELETE
    #   Nimbus Cumulus (cumulus)    - GET, POST, PUT, DELETE
    #   Eucalyptus Walrus (walrus)  - GET, POST, PUT, DELETE
    #   Hadoop HDFS (hdfs)          - GET, POST, PUT, DELETE
    #   Local Filesystem (file)     - GET, POST, PUT, DELETE
    #   Remote HTTP (http)          - GET
    #
    class Server < Goliath::API

      # Middleware
      #
      # Listen at /status for a heartbeat server message status
      use Goliath::Rack::Heartbeat
      # Auto parse and merge body and query parameters
      use Goliath::Rack::Params
      # Cleanup accepted media types
      use Goliath::Rack::DefaultMimeType


      # Routes
      #

      # @method head_image
      # @overload head '/image/:id'
      #
      # Head metadata about the image with the given id, see {Visor::Image::HeadImage}.
      #
      # The image metadata is promptly passed as a set of HTTP headers, as the following example:
      #
      #   x-image-meta-_id: <id>
      #   x-image-meta-uri: <uri>
      #   x-image-meta-name: <name>
      #   x-image-meta-architecture: <architecture>
      #   x-image-meta-access: <access>
      #   x-image-meta-status: <status>
      #   x-image-meta-size: <size>
      #   x-image-meta-format: <format>
      #   x-image-meta-store: <store>
      #   x-image-meta-location: <location>
      #   x-image-meta-created_at: <timestamp>
      #   x-image-meta-updated_at: <timestamp>
      #   x-image-meta-checksum: <checksum>
      #   x-image-meta-owner: <owner>
      #
      # @note Undefined attributes are ignored and not included into response's header.
      #   Any raised error will be passed through HTTP headers too.
      #
      # @param [String] id The wanted image _id.
      #
      # @example Retrieve the image metadata with id '19b39ed6-6c43-41cc-8d59-d1a1ed24ac9d':
      #   'HEAD /images/19b39ed6-6c43-41cc-8d59-d1a1ed24ac9d'
      #
      # @return [HTTP Headers] The image metadata.
      #
      # @raise [HTTP Error 403] If user authentication has failed.
      # @raise [HTTP Error 404] If image metadata was not found.
      # @raise [HTTP Error 503] If VIS or VAS servers were not found.
      #
      head '/images/:id', HeadImage


      # @method get_all_brief
      # @overload get '/images'
      #
      # Get brief metadata of all public and user’s private images, see {Visor::Image::GetImages}.
      #
      #   { "images":
      #     [
      #       {
      #         "_id":<_id>,
      #         "name":<name>,
      #         "architecture":<architecture>,
      #         "access":<access>
      #         "format":<format>,
      #         "size":<size>,
      #         "store":<store>
      #       },
      #       ...
      #     ]
      #   }
      #
      # The following options can be passed as query parameters, plus any other additional
      # image attribute not defined in the schema.
      #
      # @param [String, Integer, Date] parameter The image attribute to filter results based on its value.
      # @param [String] sort ("_id") The image attribute to sort results.
      # @param [String] dir ("asc") The sorting order ("asc"/"desc").
      #
      # @example Retrieve all images brief metadata:
      #   'GET /images'
      #
      # @example Retrieve all `x86_64` images brief metadata:
      #   'GET /images?architecture=x86_64'
      #
      # @example Retrieve all `.iso` images brief metadata, descending sorted by `size`:
      #   'GET /images?format=iso&sort=size&dir=desc'
      #
      # @return [JSON, XML] Images brief metadata.
      #
      # @raise [HTTP Error 403] If user authentication has failed.
      # @raise [HTTP Error 404] If no images were found.
      # @raise [HTTP Error 503] If VIS or VAS servers were not found.
      #
      get '/images', GetImages


      # @method get_all_detail
      # @overload get '/images/detail'
      #
      # Get detailed metadata of all public and user’s private images, see {Visor::Image::GetImagesDetail}.
      #
      #   { "images":
      #     [
      #       {
      #         "_id":<_id>,
      #         "uri":<uri>,
      #         "name":<name>,
      #         "architecture":<architecture>,
      #         "access":<access>,
      #         "status":<status>,
      #         "size":<size>,
      #         "type":<type>,
      #         "format":<format>,
      #         "store":<store>,
      #         "created_at":<timestamp>
      #         "updated_at":<timestamp>,
      #         "checksum":<checksum>,
      #         "owner":<owner>,
      #       },
      #       ...
      #     ]
      #   }
      #
      # The following options can be passed as query parameters, plus any other additional
      # image attribute not defined in the schema.
      #
      # @param [String, Integer, Date] parameter The image attribute to filter results based on its value.
      # @param [String] sort ("_id") The image attribute to sort results.
      # @param [String] dir ("asc") The sorting order ("asc"/"desc").
      #
      # @example Retrieve all images detailed metadata:
      #   'GET /images/detail'
      #
      # @note Querying and results sorting is made as with #get_all_brief
      #
      # @return [JSON, XML] Images detailed metadata.
      #
      # @raise [HTTP Error 403] If user authentication has failed.
      # @raise [HTTP Error 404] If no images were found.
      # @raise [HTTP Error 503] If VIS or VAS servers were not found.
      #
      get '/images/detail', GetImagesDetail


      # @method get_image
      # @overload get '/images/:id'
      #
      # Get detailed metadata and file for the image with given id, see {Visor::Image::GetImage}.
      #
      # The image data file is streamed through the response body. The server will return a 200 status code,
      # with a special HTTP header, indicating that the response body will be streamed in chunks
      # and connection shouldn't be closed until the transfer is complete.
      #
      # Also, the image metadata is promptly passed as a set of HTTP headers, as the following example:
      #
      #   x-image-meta-_id: <id>
      #   x-image-meta-uri: <uri>
      #   x-image-meta-name: <name>
      #   x-image-meta-architecture: <architecture>
      #   x-image-meta-access: <access>
      #   x-image-meta-status: <status>
      #   x-image-meta-size: <size>
      #   x-image-meta-format: <format>
      #   x-image-meta-store: <store>
      #   x-image-meta-location: <location>
      #   x-image-meta-created_at: <timestamp>
      #   x-image-meta-updated_at: <timestamp>
      #   x-image-meta-checksum: <checksum>
      #   x-image-meta-owner: <owner>
      #
      # @note Undefined attributes are ignored and not included into response's header.
      #
      # @param [String] id The wanted image _id.
      #
      # @example Retrieve the image with id '19b39ed6-6c43-41cc-8d59-d1a1ed24ac9d':
      #   'GET /images/19b39ed6-6c43-41cc-8d59-d1a1ed24ac9d'
      #
      # @return [HTTP Headers] The image metadata.
      # @return [HTTP Body] The image file.
      #
      # @raise [HTTP Error 403] If user authentication has failed.
      # @raise [HTTP Error 404] If the image metadata was not found.
      # @raise [HTTP Error 404] If the image file was not found.
      # @raise [HTTP Error 503] If VIS or VAS servers were not found.
      #
      get '/images/:id', GetImage


      # @method post
      # @overload post '/images'
      #
      # Post image data and metadata and returns the registered metadata, see {Visor::Image::PostImage}.
      #
      # The image metadata should be encoded as HTTP headers and passed with the request, as the following example:
      #
      #   x-image-meta-name:          Ubuntu 10.10 Desktop
      #   x-image-meta-architecture:  i386
      #   x-image-meta-store:         s3
      #
      # If wanted, the image data file should be streamed through the request body.
      # The server will receive that data in chunks, buffering them to a properly secured temporary
      # file, avoiding buffering all the data into memory. The server will then handle the upload of that
      # file to the definitive store location, cleaning then the generated temporary file.
      #
      # Alternatively, a *x-image-meta-location* header can be passed, if the file is already stored in some
      # provided location. If this header is present, no body content can be passed in the request.
      #
      # @return [JSON, XML] The already created image detailed metadata.
      #
      # @raise [HTTP Error 400] If the image metadata validation fails.
      # @raise [HTTP Error 400] If the location header is present no file content can be provided.
      # @raise [HTTP Error 400] If trying to post an image file to a HTTP backend.
      # @raise [HTTP Error 400] If provided store is an unsupported store backend.
      # @raise [HTTP Error 403] If user authentication has failed.
      # @raise [HTTP Error 404] If no image file is found at the provided location.
      # @raise [HTTP Error 409] If the provided image file already exists in the backend store.
      # @raise [HTTP Error 503] If VIS or VAS servers were not found.
      #
      post '/images', PostImage


      # @method put
      # @overload put '/images/:id'
      #
      # Put image metadata and/or data for the image with the given id, see {Visor::Image::PutImage}.
      #
      # The image metadata should be encoded as HTTP headers and passed with the request, as the following example:
      #
      #   x-image-meta-name:          Ubuntu 10.10 Server
      #   x-image-meta-architecture:  x86_64
      #   x-image-meta-location:      http://www.ubuntu.com/start-download?distro=server&bits=64&release=latest
      #
      # If wanted, the image data file should be streamed through the request body.
      # The server will receive that data in chunks, buffering them to a properly secured temporary
      # file, avoiding buffering all the data into memory. Server will then handle the upload of that
      # data to the definitive store location, cleaning then the generated temporary file.
      #
      # Alternatively, a *x-image-meta-location* header can be passed, if the file is already stored in some
      # provided location. If this header is present, no body content can be passed in the request.
      #
      # @note Only images with status set to 'locked' or 'error' can be updated with an image data file.
      #
      # @return [JSON, XML] The already updated image detailed metadata.
      #
      # @raise [HTTP Error 400] If the image metadata validation fails.
      # @raise [HTTP Error 400] If no headers neither body found for update.
      # @raise [HTTP Error 400] If the location header is present no file content can be provided.
      # @raise [HTTP Error 400] If trying to post an image file to a HTTP backend.
      # @raise [HTTP Error 400] If provided store is an unsupported store backend.
      # @raise [HTTP Error 403] If user authentication has failed.
      # @raise [HTTP Error 404] If no image data is found at the provided location.
      # @raise [HTTP Error 409] If trying to assign image file to a locked or uploading image.
      # @raise [HTTP Error 409] If the provided image file already exists in the backend store.
      # @raise [HTTP Error 503] If VIS or VAS servers were not found.
      #
      put '/images/:id', PutImage


      # @method delete
      # @overload delete '/images/:id'
      #
      # Delete the metadata and file of the image with the given id, see {Visor::Image::DeleteImage}.
      #
      # @param [String] id The image _id to delete.
      #
      # @example Delete the image with id '19b39ed6-6c43-41cc-8d59-d1a1ed24ac9d':
      #   'DELETE /images/19b39ed6-6c43-41cc-8d59-d1a1ed24ac9d'
      #
      # @return [JSON, XML] The already deleted image detailed metadata.
      #
      # @raise [HTTP Error 403] If user authentication has failed.
      # @raise [HTTP Error 403] If user does not have permission to manipulate the image file.
      # @raise [HTTP Error 404] If image metadata was not found.
      # @raise [HTTP Error 503] If VIS or VAS servers were not found.
      #
      delete '/images/:id', DeleteImage

      delete '/all', DeleteAllImages

      # Not Found
      not_found('/') do
        run Proc.new { |env| [404, {}, {code: 404, message: "Invalid operation or path."}.to_json] }
      end
    end

  end
end
