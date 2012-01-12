require 'goliath'
require 'json'

require File.expand_path('../../meta', __FILE__)

#TODO: gzip, https, correct json formatting
module Visor
  module Meta

    class GetImages < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          images = db.get_public_images(true, params)
          [200, {}, {images: images}.to_json]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

    class GetImagesDetail < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          images = db.get_public_images(false, params)
          [200, {}, {images: images}]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

    class GetImage < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          image = db.get_image(params[:id])
          [200, {}, {image: image}]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

    class PostImage < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def on_body(env, data)
        env['body'] = data
      end

      def response(env)
        begin
          meta  = JSON.parse(env['body'], symbolize_names: true)
          image = db.post_image(meta[:image])
          [200, {}, {image: image}]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        rescue ArgumentError => e
          [400, {}, {code: 400, message: e.message}]
        end
      end
    end

    class PutImage < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def on_body(env, data)
        env['body'] = data
      end

      def response(env)
        begin
          meta  = JSON.parse(env['body'], symbolize_names: true)
          image = db.put_image(params[:id], meta[:image])
          [200, {}, {image: image}]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        rescue ArgumentError => e
          [400, {}, {code: 400, message: e.message}]
        end
      end
    end

    class DeleteImage < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          image = db.delete_image(params[:id])
          [200, {}, {image: image}]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

    # The VISoR Meta Server class. This class supports all image metadata manipulation
    # operations through the VISoR REST API implemented along the following routes.
    #
    # After initialize the Server its possible to directly interact with the meta backend.
    #
    class Server < Goliath::API

      # Include Middleware
      #
      use Goliath::Rack::Heartbeat # respond to /status with 200, OK (monitoring, etc)
      use Goliath::Rack::Params    # parse & merge query and body parameters
      use Goliath::Rack::Validation::RequestMethod, %w(GET POST PUT DELETE)

      # Routes
      #
      # @method get_all_brief
      # @overload get '/images'
      #
      # Get brief information about all public images.
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
      #       "created_at":<creation timestamp>
      #       }, ...]}
      #
      # The following options can be passed as query parameters, plus any other additional
      # image attribute not defined in the schema.
      #
      # @param [String] name The image name.
      # @param [String] architecture The image architecture.
      # @param [String] type The image type.
      # @param [String] format The image format.
      # @param [String] store The image store.
      # @param [Fixnum] size The image size.
      # @param [Date] created_at The image creation timestamp.
      # @param [String] sort ('_id') The image attribute to sort results.
      # @param [String] dir ('asc') The sorting order ('asc'/'desc').
      #
      # @return [JSON] The public images brief metadata.
      #
      # @raise [HTTP Error 404] If there is no public images.
      #
      get '/images', GetImages


      # @method get_all_detail
      # @overload get '/images/detail'
      #
      # Get detailed information about all public images.
      #
      #   {"images": [{
      #       "_id":<_id>,
      #       "uri":<uri>,
      #       "name":<name>,
      #       "architecture":<architecture>,
      #       "access":<access>,
      #       "status":<status>,
      #       "size":<size>,
      #       "type":<type>,
      #       "format":<format>,
      #       "store":<type>,
      #       "created_at":<creation timestamp>
      #       "updated_at":<update timestamp>,
      #       "kernel":<associated kernel>,
      #       "ramdisk":<associated ramdisk>,
      #       ...
      #       }, ...]}
      #
      # The following options can be passed as query parameters, plus any other additional
      # image attribute not defined in the schema.
      #
      # @param [String] name The image name.
      # @param [String] architecture The image architecture.
      # @param [String] access The image access permission.
      # @param [String] type The image type.
      # @param [String] format The image format.
      # @param [String] store The image store.
      # @param [Fixnum] size The image size.
      # @param [Date] created_at The image creation timestamp.
      # @param [Date] updated_at The image update timestamp.
      # @param [String] kernel The image associated kernel image's _id.
      # @param [String] ramdisk The image associated kernel image's _id.
      # @param [String] sort (_id) The image attribute to sort results.
      # @param [String] dir ('asc') The sorting order ('asc'/'desc').
      #
      # @return [JSON] The public images detailed metadata.
      #
      # @raise [HTTP Error 404] If there is no public images.
      #
      get '/images/detail', GetImagesDetail


      # @method get_detail
      # @overload get '/images/:id'
      #
      # Get detailed information about a specific image.
      #
      #   {"image": {
      #       "_id":<_id>,
      #       "uri":<uri>,
      #       "name":<name>,
      #       "architecture":<architecture>,
      #       "access":<access>,
      #       "status":<status>,
      #       "size":<size>,
      #       "type":<type>,
      #       "format":<format>,
      #       "store":<type>,
      #       "created_at":<creation timestamp>
      #       "updated_at":<update timestamp>,
      #       "kernel":<associated kernel>,
      #       "ramdisk":<associated ramdisk>,
      #       ...
      #   }}
      #
      # @param [String] id The wanted image _id.
      #
      # @return [JSON] The image detailed metadata.
      #
      # @raise [HTTP Error 404] If image not found.
      #
      get '/images/:id', GetImage


      # @method post
      # @overload post '/images'
      #
      # Create a new image metadata and returns it.
      #
      # @param [JSON] http-body The image metadata.
      #
      # @return [JSON] The already created image detailed metadata.
      #
      # @raise [HTTP Error 400] Image metadata validation errors.
      #
      post '/images', PostImage


      # @method put
      # @overload put '/images/:id'
      #
      # Update an existing image metadata and return it.
      #
      # @param [String] id The wanted image _id.
      # @param [JSON] http-body The image metadata.
      #
      # @return [JSON] The already updated image detailed metadata.
      #
      # @raise [HTTP Error 400] Image metadata update validation errors.
      #
      put '/images/:id', PutImage


      # @method delete
      # @overload delete '/images/:id'
      #
      # Delete an image metadata and returns it.
      #
      # @param [String] id The image _id to delete.
      #
      # @return [JSON] The already deleted image detailed metadata.
      #
      # @raise [HTTP Error 404] If image not found.
      #
      delete '/images/:id', DeleteImage

      # Not Found
      #
      not_found('/') do
        run Proc.new { |env| [404, {}, {code: 404, message: "Invalid operation or path."}] }
      end
    end

  end
end
