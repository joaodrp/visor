require 'goliath'
require 'tempfile'
require 'json'

require File.expand_path('../../api', __FILE__)

#TODO: Include cache with Etag header set to image['checksum']?

module Visor
  module API

    # The VISoR API Server. This supports all image metadata manipulation
    # operations, dispatched to the VISoR Meta Server and the image files storage operations.
    #
    # The Server API is a RESTful web service for image meta as follows:
    #
    #   HEAD    /images/<id>    - Returns metadata about the image with the given id
    #   GET     /images         - Returns a set of brief metadata about all public images
    #   GET     /images/detail  - Returns a set of detailed metadata about all public images
    #   GET     /images/<id>    - Returns image data and metadata for the image with the given id
    #   POST    /images         - Stores a new image data and metadata and returns the registered metadata
    #   PUT     /images/<id>    - Update image metadata and/or data for the image with the given id
    #   DELETE  /images/<id>    - Delete the metadata and data of the image with the given id
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
      # Head metadata about the image with the given id, see {Visor::API::HeadImage}.
      head '/images/:id', HeadImage


      # @method get_all_brief
      # @overload get '/images'
      #
      # Get brief information about all public images, see {Visor::API::GetImages}.
      #
      #   { "images": [{
      #       "_id":<_id>,
      #       "uri":<uri>,
      #       "name":<name>,
      #       "architecture":<architecture>,
      #       "type":<type>,
      #       "format":<format>,
      #       "store":<type>,
      #       "size":<size>,
      #       "created_at":<timestamp>
      #       }, ...]}
      #
      # The following options can be passed as query parameters, plus any other additional
      # image attribute not defined in the schema.
      #
      # @param [String, Integer, Date] parameter The image attribute to filter results based on its value.
      # @param [String] sort ("_id") The image attribute to sort results.
      # @param [String] dir ("asc") The sorting order ("asc"/"desc").
      #
      # @example Retrieve all public images brief metadata:
      #   'GET /images'
      #
      # @example Retrieve all public `x86_64` images brief metadata:
      #   'GET /images?architecture=x86_64'
      #
      # @example Retrieve all public `.iso` images brief metadata, descending sorted by `size`:
      #   'GET /images?format=iso&sort=size&dir=desc'
      #
      # @return [JSON] The public images brief metadata.
      #
      # @raise [HTTP Error 404] If there is no public images.
      # @raise [HTTP Error 500] On internal server error.
      #
      get '/images', GetImages

      # Get detailed information about all public images, see {Visor::API::GetImagesDetail}.
      get '/images/detail', GetImagesDetail

      # Get image data and metadata for the given id, see {Visor::API::GetImage}.
      get '/images/:id', GetImage

      # Post image data and metadata and returns the registered metadata, see {Visor::API::PostImage}.
      post '/images', PostImage

      # Put image metadata and/or data for the image with the given id
      put '/images/:id', PutImage

      # Delete the metadata and data of the image with the given id, see {Visor::API::DeleteImage}.
      delete '/images/:id', DeleteImage

      #TODO: remove this
      delete '/all', DeleteAllImages

      # Not Found
      not_found('/') do
        run Proc.new { |env| [404, {}, {code: 404, message: "Invalid operation or path."}.to_json] }
      end
    end

  end
end
