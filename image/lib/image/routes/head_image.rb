require 'goliath'

module Visor
  module Image

    # Head metadata about the image with the given id.
    #
    class HeadImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util

      # Pre-process headers as they arrive and load them into a environment variable.
      #
      # @param [Object] env The Goliath environment variables.
      # @param [Object] headers The incoming request HTTP headers.
      #
      def on_headers(env, headers)
        logger.debug "Received headers: #{headers.inspect}"
        env['headers'] = headers
      end

      # Query database to retrieve the wanted image meta and return it as HTTP headers.
      #
      # @param [Object] env The Goliath environment variables.
      #
      def response(env)
        authorize(env, vas)
        meta   = vms.get_image(params[:id])
        header = push_meta_into_headers(meta)
        [200, header, nil]
      rescue Forbidden => e
        exit_error(403, e.message)
      rescue NotFound => e
        exit_error(404, e.message)
      rescue InternalError => e
        exit_error(503, e.message)
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
        [code, {'x-error-code' => code.to_s, 'x-error-message' => message}, nil]
      end
    end

  end
end
