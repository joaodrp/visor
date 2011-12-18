require 'sinatra/base'
require 'json'
require File.expand_path '../../registry', __FILE__

# TODO: compressing and caching
module Visor
  module Registry

    # The VISoR Registry Server class. This class supports all image metadata manipulation
    # operations through the VISoR REST API implemented allong the following routes.
    #
    # After initialize the Server its possible to directly interact with the registry backend.
    #
    class Server < Sinatra::Base

      include Visor::Common::Exception
      include Visor::Common::Config

      CONF = Common::Config.load_config :registry_server
      LOG  = Common::Config.build_logger :registry_server

      HOST = CONF[:bind_host] || '0.0.0.0'
      PORT = CONF[:bind_port] || 4567
      URI  = CONF[:backend] || "mongodb://:@#{HOST}:#{PORT}/visor"

      # Configuration
      #
      configure do
        use Rack::CommonLogger, LOG

        backend_map = {'mongodb' => Visor::Registry::Backends::MongoDB,
                       'mysql'   => Visor::Registry::Backends::MySQL}

        DB = backend_map[URI.split(':').first].connect uri: URI

        enable :threaded
        disable :show_exceptions, :protection
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
      #       "_id"":<_id>,
      #       "name":<name>,
      #       "architecture":<architecture>,
      #       "type":<type>,
      #       "format":<format>,
      #       "store":<type>
      #       }, ...]}
      #
      # @param [String] Any available field values can be passed as query parameters,
      #   plus the sort=<attribute> and dir=<asc/desc> parameters.
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
      #       "updated_at":<updated_at>,
      #       "kernel":<associated kernel>,
      #       "ramdisk":<associated ramdisk>,
      #       "others":<others>
      #       }, ...]}
      #
      # @param [String] Any available field values can be passed as query parameters,
      #   plus the sort=<attribute> and dir=<asc/desc> parameters.
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
      #   {"images": {
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
      #       "updated_at":<updated_at>,
      #       "kernel":<associated kernel>,
      #       "ramdisk":<associated ramdisk>,
      #       "others":<others>
      #   }}
      #
      # @param [Integer] id The wanted image id.
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
      # @param [JSON] The image metadata.
      #
      # @return [JSON] The image detailed metadata.
      #
      # @raise [HTTP Error 400] Image metadata validation errors.
      #
      post '/images' do
        begin
          meta  = JSON.parse(request.body.read, @parse_opts)
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
      # @param [Integer] id The wanted image id.
      # @param [JSON] The image metadata update.
      #
      # @return [JSON] The image detailed metadata.
      #
      # @raise [HTTP Error 400] Image metadata update validation errors.
      #
      put '/images/:id' do |id|
        begin
          meta  = JSON.parse(request.body.read, @parse_opts)
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
      # Delete an image metadata and return it.
      #
      # @param [Integer] id The image id to delete.
      #
      # @return [JSON] The image detailed metadata.
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

if __FILE__ == $0
  conf = Visor::Common::Config.load_config :registry_server
  host = conf[:bind_host] || '0.0.0.0'
  port = conf[:bind_port] || 4567

  Visor::Registry::Server.run! bind: host, port: port, environment: :development
end


