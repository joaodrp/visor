module Visor
  module API

    # Get image data and metadata for the given id.
    #
    class GetImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, ['json', 'xml']

      def response(env)
        begin
          meta = vms.get_image(params[:id])
          uri  = meta[:location]
          if uri
            store = Visor::API::Store.get_backend(uri, configs)
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

      def on_close(env)
        logger.info 'Connection closed'
      end

      def exit_error(code, message)
        logger.error message
        [code, {}, {code: code, message: message}]
      end
    end

  end
end
