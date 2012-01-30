require 'goliath'

module Visor
  module API

    # Get detailed information about all public images.
    #
    class GetImagesDetail < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, ['json', 'xml']

      # Query database to retrieve the public images detailed meta and return it in request body.
      #
      # @param [Object] env The Goliath environment variables.
      #
      # @return [Array] The HTTP response containing the images
      #   metadata or an error code and its messages if anything was raised.
      #
      def response(env)
        meta = vms.get_images_detail(params)
        [200, {}, {images: meta}]
      rescue NotFound => e
        exit_error(404, e.message)
      rescue => e
        exit_error(500, e.message)
      end

      # Produce an HTTP response with an error code and message.
      #
      # @param [Fixnum] code The error code.
      # @param [String] message The error message.
      #
      # @return [Array] The HTTP response containing an error code and its message.
      #
      def exit_error(code, message)
        logger.error message
        [code, {}, {code: code, message: message}]
      end
    end

  end
end
