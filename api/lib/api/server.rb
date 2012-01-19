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
          Visor::API::Store.file_exists?(uri)
        rescue NotFound => e
          return [404, {}, {code: 404, message: e.message}]
        end

        store = Visor::API::Store.get_backend(uri: uri)

        operation = proc do
          store.get(uri) { |chunk| env.stream_send chunk }
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

      def exit_error(code, message)
        [code, {}, {code: code, message: message}]
      end

      def insert_meta
        meta = DB.post_image(@meta.merge(size: 0)) # will set its status to locked
        @id  = meta[:_id]
        meta
      end

      def update_meta(update)
        DB.put_image(@id, update)
      end

      def update_status_and_upload
        @meta = update_meta(status: 'uploading')

        location, size, checksum = upload_image_file
        update_meta(status: 'available', location: location, size: size, checksum: checksum)
      end

      def upload_image_file
        content_type = @headers['Content-Type'] || ''
        store_name   = @meta[:store] || STORE_CONF[:default]
        format       = @meta[:format] || 'none'
        opts         = STORE_CONF[store_name.to_sym]

        unless content_type == 'application/octet-stream'
          update_meta(status: 'error')
          raise ArgumentError, 'Request Content-Type must be application/octet-stream'
        end

        store = Visor::API::Store.get_backend(name: store_name)
        update_meta(status: 'uploading')
        store.save(@id, @body, format, opts)
      end

      def on_headers(env, headers)
        @headers = headers
        @meta    = pull_meta_from_headers(headers)
      end

      def on_body(env, data)
        @body ||= Tempfile.open('visor-image', '~/tmp', encoding: 'ascii-8bit')
        @body << data
      end

      def response(env)
        begin
          @meta = insert_meta
        rescue ArgumentError => e
          @body.unlink if @body
          return exit_error(400, e.message)
        rescue InternalError => e
          @body.unlink if @body
          return exit_error(500, e.message)
        end

        if @body
          begin
            @meta = update_status_and_upload
          rescue UnsupportedStore, ArgumentError => e
            return exit_error(400, e.message)
          rescue NotFound => e
            return exit_error(404, e.message)
          ensure
            @body.unlink
          end
          [200, {}, {head: @headers, meta: @meta}]
        else
          [200, {}, {head: @headers, meta: @meta}]
        end
      end
    end


    class DeleteAllImages < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          images = DB.get_images
          images.each { |image| DB.delete_image(image[:_id]) }
          [200, {}, nil]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
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

      delete '/images/all', DeleteAllImages
      # Not Found
      not_found('/') do
        run Proc.new { |env| [404, {}, {code: 404, message: "Invalid operation or path."}] }
      end
    end

  end
end
