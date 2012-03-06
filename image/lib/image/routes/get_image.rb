require 'goliath'

module Visor
  module Image

    # Get image data and metadata for the given id.
    #
    class GetImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, ['json', 'xml']

      # Query database to retrieve the wanted image meta and return it in
      # headers, along with the image file, if any, streaming it in request body.
      #
      # @param [Object] env The Goliath environment variables.
      #
      def response(env)
        begin
          meta = vms.get_image(params[:id])
          uri  = meta[:location]
          if uri
            store = Visor::Image::Store.get_backend(uri, configs)
            store.file_exists?
          end
        rescue NotFound => e
          return exit_error(404, e.message)
        rescue => e
          return exit_error(500, e.message)
        end

        custom  = {'Content-Type' => 'application/octet-stream', 'X-Stream' => 'Goliath'}
        headers = push_meta_into_headers(meta, custom)

        if uri
          EM.next_tick do
            store.get { |chunk| chunk ? env.chunked_stream_send(chunk) : env.chunked_stream_close }
          end
          chunked_streaming_response(200, headers)
        else
          [200, headers, nil]
        end
      end

      # On connection close log a message.
      #
      # @param [Object] env The Goliath environment variables.
      #
      def on_close(env)
        logger.info 'Connection closed'
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
