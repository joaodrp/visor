require 'goliath'
require 'json'

require File.expand_path('../../api', __FILE__)

conf = Visor::Common::Config.load_config :meta_server
META = Visor::API::Meta.new(host: conf[:bind_host], port: conf[:bind_port])

#TODO: Include cache with Etag header set to image['checksum']?

module Visor
  module API

    # Head metadata about the image with the given id.
    #
    class HeadImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          meta   = META.get_image(params[:id])
          header = push_meta_into_headers(meta)
          [200, header, nil]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

    # Get brief information about all public images.
    #
    class GetImages < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          meta = META.get_images(params)
          [200, {}, {images: meta}]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

    # Get detailed information about all public images.
    #
    class GetImagesDetail < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          meta = META.get_images_detail(params)
          [200, {}, {images: meta}]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

    # Get image data and metadata for the given id.
    #
    class GetImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          meta = META.get_image(params[:id])
          uri  = meta[:location]
          Visor::API::Store.file_exists? uri
        rescue NotFound => e
          return [404, {}, {code: 404, message: e.message}]
        end

        headers = push_meta_into_headers(meta)

        #EM.error_handler do |e|
        #  EM.stop
        #end

        operation = proc do
          Visor::API::Store.get(uri) { |chunk| env.stream_send(chunk) }
        end

        callback = proc do |result|
          env.stream_close
        end
        #EM.next_tick do
        #  Visor::API::Store.get(uri) { |chunk| env.stream_send(chunk) }
        #  env.stream_close
        #end

        EM.defer operation, callback

        headers.merge!('Content-Type' => 'application/octet-stream', 'X-Stream' => 'Goliath')
        [200, headers, Goliath::Response::STREAMING]
      end
    end


    # The VISoR API Server. This supports all image metadata manipulation
    # operations, dispatched to the VISoR Meta Server and the image files storage operations.
    #
    # The Server API is a RESTful web service for image meta as follows:
    #
    # HEAD    /images/<id>    - Returns metadata about the image with the given id
    # GET     /images         - Returns a set of brief metadata about all public images
    # GET     /images/detail  - Returns a set of detailed metadata about all public images
    # GET     /images/<id>    - Returns image data and metadata for the image with the given id
    # POST    /images         - Stores a new image data and metadata, returns the already registered metadata
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

      # Not Found
      not_found('/') do
        run Proc.new { |env| [404, {}, {code: 404, message: "Invalid operation or path."}] }
      end
    end

  end
end
