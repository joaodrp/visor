require 'sinatra/base'
require 'json'

# TODO: compressing and caching
module Visor
  module Meta

    # The VISoR Meta Server class. This class supports all image metadata manipulation
    # operations through the VISoR REST API implemented allong the following routes.
    #
    # After initialize the Server its possible to directly interact with the meta backend.
    #
    class Server < Sinatra::Base

      include Visor::Common::Exception
      include Visor::Common::Config

      # Configuration
      #
      configure do
        backend_map = {'mongodb' => Visor::Meta::Backends::MongoDB,
                       'mysql' => Visor::Meta::Backends::MySQL}

        conf = Visor::Common::Config.load_config(:meta_server)
        log = Common::Config.build_logger(:meta_server)

        DB = backend_map[conf[:backend].split(':').first].connect uri: conf[:backend]

        enable :threaded
        disable :show_exceptions, :protection

        use Rack::CommonLogger, log
      end

      configure :development do
        require 'sinatra/reloader'
        register Sinatra::Reloader
      end

      # Helpers
      #
      helpers do
        def json_error(code, message)
          error code, {code: code, message: message}.to_json
        end
      end

      # Filters
      #
      before do
        @parse_opts = {symbolize_names: true}
        content_type :json
      end

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
      get '/images' do
        begin
          images = DB.get_public_images(true, params)
          {images: images}.to_json
        rescue NotFound => e
          json_error 404, e.message
        end
      end

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
      get '/images/detail' do
        begin
          images = DB.get_public_images(false, params)
          {images: images}.to_json
        rescue NotFound => e
          json_error 404, e.message
        end
      end

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
      get '/images/:id' do |id|
        begin
          image = DB.get_image(id)
          {image: image}.to_json
        rescue NotFound => e
          json_error 404, e.message
        end
      end

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
      post '/images' do
        begin
          meta = JSON.parse(request.body.read, @parse_opts)
          image = DB.post_image(meta[:image])
          {image: image}.to_json
        rescue NotFound => e
          json_error 404, e.message
        rescue ArgumentError => e
          json_error 400, e.message
        end
      end

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
      put '/images/:id' do |id|
        begin
          meta = JSON.parse(request.body.read, @parse_opts)
          image = DB.put_image(id, meta[:image])
          {image: image}.to_json
        rescue NotFound => e
          json_error 404, e.message
        rescue ArgumentError => e
          json_error 400, e.message
        end
      end

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
      delete '/images/:id' do
        begin
          image = DB.delete_image(params[:id])
          {image: image}.to_json
        rescue NotFound => e
          json_error 404, e.message
        end
      end

      # misc handlers: error, not_found, etc.
      get "*" do
        json_error 404, 'Invalid operation or path.'
      end

      put "*" do
        json_error 404, 'Invalid operation or path.'
      end

      post "*" do
        json_error 404, 'Invalid operation or path.'
      end

      delete "*" do
        json_error 404, 'Invalid operation or path.'
      end

      error do
        json_error 500, env['sinatra.error'].message
      end

    end
  end
end


