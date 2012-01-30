module Visor
  module API

    # Get detailed information about all public images.
    #
    class GetImagesDetail < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, ['json', 'xml']

      def response(env)
        meta = vms.get_images_detail(params)
        [200, {}, {images: meta}]
      rescue NotFound => e
        exit_error(404, e.message)
      rescue => e
        exit_error(500, e.message)
      end

      def exit_error(code, message)
        logger.error message
        [code, {}, {code: code, message: message}]
      end
    end

  end
end
