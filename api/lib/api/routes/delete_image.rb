module Visor
  module API

    # Delete the metadata and data of the image with the given id.
    #
    class DeleteImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          meta   = DB.delete_image(params[:id])
          uri    = meta[:location]
          name   = meta[:store] || STORE_CONF[:default]
          config = STORE_CONF[name.to_sym]

          store  = Visor::API::Store.get_backend(uri, config)
          store.delete
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        rescue Unauthorized => e
          [550, {}, {code: 550, message: e.message}]
        rescue => e
          [500, {}, {code: 500, message: e.message}]
        else
          [200, {}, {image: meta}]
        end
      end
    end

  end
end
