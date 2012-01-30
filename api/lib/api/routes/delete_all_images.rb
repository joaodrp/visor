require 'goliath'

module Visor
  module API

    # Delete all images metadata
    #
    class DeleteAllImages < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        images = vms.get_images
        images.each { |image| vms.delete_image(image[:_id]) }
        [200, {}, nil]
      rescue Unauthorized => e
        exit_error(550, e.message)
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
