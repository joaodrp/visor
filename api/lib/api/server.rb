require 'goliath'
require 'json'
require 'tempfile'

require File.expand_path('../../api', __FILE__)

conf       = Visor::Common::Config.load_config
META_CONF  = conf[:visor_meta]
API_CONF   = conf[:visor_api]
STORE_CONF = conf[:visor_store]
DB         = Visor::API::Meta.new(host: META_CONF[:bind_host], port: META_CONF[:bind_port])

#TODO: Include cache with Etag header set to image['checksum']?

module Visor
  module API

    # The VISoR API Server. This supports all image metadata manipulation
    # operations, dispatched to the VISoR Meta Server and the image files storage operations.
    #
    # The Server API is a RESTful web service for image meta as follows:
    #
    # HEAD    /images/<id>    - Returns metadata about the image with the given id
    # GET     /images         - Returns a set of brief metadata about all public images
    # GET     /images/detail  - Returns a set of detailed metadata about all public images
    # GET     /images/<id>    - Returns image data and metadata for the image with the given id
    # POST    /images         - Stores a new image data and metadata and returns the registered metadata
    # PUT     /images/<id>    - Update image metadata and/or data for the image with the given id
    # DELETE  /images/<id>    - Delete the metadata and data of the image with the given id
    #
    class Server < Goliath::API

      # Middleware
      #
      # Listen at /status for a heartbeat server message status
      use Goliath::Rack::Heartbeat
      # Auto parse and merge body and query parameters
      use Goliath::Rack::Params

      # Routes
      #
      # Head metadata about the image with the given id, see {Visor::API::HeadImage}.
      head '/images/:id', HeadImage

      # Get brief information about all public images, see {Visor::API::GetImages}.
      get '/images', GetImages

      # Get detailed information about all public images, see {Visor::API::GetImagesDetail}.
      get '/images/detail', GetImagesDetail

      # Get image data and metadata for the given id, see {Visor::API::GetImage}.
      get '/images/:id', GetImage

      # Post image data and metadata and returns the registered metadata, see {Visor::API::PostImage}.
      post '/images', PostImage

      #TODO: remove this
      delete '/images/all', DeleteAllImages

      # Not Found
      not_found('/') do
        run Proc.new { |env| [404, {}, {code: 404, message: "Invalid operation or path."}] }
      end
    end

  end
end
