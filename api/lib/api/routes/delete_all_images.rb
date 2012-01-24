module Visor
  module API

    # Delete all images metadata TODO: delete this
    #
    class DeleteAllImages < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          images = DB.get_images
          images.each do |image|
            if uri = image[:location]
              name   = image[:store] || STORE_CONF[:default]
              config = STORE_CONF[name.to_sym]
              store  = Visor::API::Store.get_backend(uri, config)
              store.delete
            end
            DB.delete_image(image[:_id])
          end
          [200, {}, nil]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

  end
end
