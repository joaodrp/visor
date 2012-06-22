require 'goliath'

module Visor
  module Image

    # Delete all images metadata
    #
    class DeleteAllImages < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      # Pre-process headers as they arrive and load them into a environment variable.
      #
      # @param [Object] env The Goliath environment variables.
      # @param [Object] headers The incoming request HTTP headers.
      #
      def on_headers(env, headers)
        logger.debug "Received headers: #{headers.inspect}"
        env['headers'] = headers
      end

      def response(env)
        authorize(env, vas)
        images = vms.get_images
        images.each { |image| vms.delete_image(image[:_id]) }
        [200, {}, nil]
      rescue Forbidden => e
        exit_error(403, e.message)
      rescue NotFound => e
        exit_error(404, e.message)
      rescue InternalError => e
        exit_error(503, e.message)
      end

      def exit_error(code, message)
        logger.error message
        [code, {}, {code: code, message: message}]
      end
    end

  end
end
