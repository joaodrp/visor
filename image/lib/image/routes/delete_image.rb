require 'goliath'

module Visor
  module Image

    # Delete the metadata and data of the image with the given id.
    #
    class DeleteImage < Goliath::API
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

      # Query database to delete the wanted image based on its id.
      #
      # @param [Object] env The Goliath environment variables.
      #
      # @return [Array] The HTTP response containing the image
      #   metadata or an error code and its messages if anything was raised.
      #
      def response(env)
        authorize(env, vas)
        meta = vms.delete_image(params[:id])
        uri  = meta[:location]
        name = meta[:store]

        if uri && name
          store = Visor::Image::Store.get_backend(uri, configs)
          store.delete unless name == 'http'
        end
      rescue Forbidden => e
        exit_error(403, e.message)
      rescue NotFound => e
        exit_error(404, e.message)
      rescue InternalError => e
        exit_error(503, e.message)
      else
        [200, {}, {image: meta}]
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
