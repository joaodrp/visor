require 'goliath'

module Visor
  module Image

    # Get detailed information about all public images.
    #
    class GetImagesDetail < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, ['json', 'xml']

      # Pre-process headers as they arrive and load them into a environment variable.
      #
      # @param [Object] env The Goliath environment variables.
      # @param [Object] headers The incoming request HTTP headers.
      #
      def on_headers(env, headers)
        logger.debug "Received headers: #{headers.inspect}"
        env['headers'] = headers
      end

      # Query database to retrieve the public images detailed meta and return it in request body.
      #
      # @param [Object] env The Goliath environment variables.
      #
      # @return [Array] The HTTP response containing the images
      #   metadata or an error code and its messages if anything was raised.
      #
      def response(env)
        access_key = authorize(env, vas)
        meta = vms.get_images_detail(params, access_key)
        [200, {}, {images: meta}]
      rescue Forbidden => e
        exit_error(403, e.message)
      rescue NotFound => e
        exit_error(404, e.message)
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
