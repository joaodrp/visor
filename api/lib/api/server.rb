require 'goliath'
require 'json'

require File.expand_path('../../api', __FILE__)

conf = Visor::Common::Config.load_config :visor_meta
DB = Visor::API::Meta.new(host: conf[:bind_host], port: conf[:bind_port])

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
          meta   = DB.get_image(params[:id])
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
          meta = DB.get_images(params)
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
          meta = DB.get_images_detail(params)
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

      def default_headers
        {'Content-Type' => 'application/octet-stream',
         'X-Stream'     => 'Goliath'}
      end

      def response(env)
        begin
          meta = DB.get_image(params[:id])
          uri  = meta[:location]
          Visor::API::Store.file_exists? uri
        rescue NotFound => e
          return [404, {}, {code: 404, message: e.message}]
        end

        operation = proc do
          Visor::API::Store.get(uri) { |chunk| env.stream_send chunk }
        end

        callback = proc { env.stream_close }
        EM.defer operation, callback

        headers = push_meta_into_headers(meta, default_headers)
        [200, headers, Goliath::Response::STREAMING]
      end
    end

    # Post image data and metadata and returns the registered metadata.
    #
    class PostImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      def insert_meta
        meta        = pull_meta_from_headers(env['headers'])
        meta[:size] = 0
        DB.post_image(meta) # will set its status to locked
      end

      def exit_with_error(code, message)
        [code, {}, {code: code, message: message}]
      end

      def on_headers(env, headers)
        env['headers'] = headers
      end

      def on_body(env, data)
        (env['body'] ||= '') << data
      end

      def response(env)
        begin
          meta = insert_meta
        rescue Invalid, ArgumentError => e
          return exit_with_error(404, e.message)
        end

        unless env['body'].nil?
          begin
            meta = update_status_and_upload(meta)
          rescue => e
            return exit_with_error(404, e.message)
          end
        end
        [200, {}, {}]
      end

      def update_status_and_upload(meta)
        id = meta[:_id]
        DB.put_image(id, {status: 'uploading'})
        location = upload(meta)
        DB.put_image(id, {status: 'available', location: location})
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

      # Not Found
      not_found('/') do
        run Proc.new { |env| [404, {}, {code: 404, message: "Invalid operation or path."}] }
      end
    end

  end
end
