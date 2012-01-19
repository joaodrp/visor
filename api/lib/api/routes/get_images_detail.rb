module Visor
  module API

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

  end
end
