module Visor
  module API

    # Get image data and metadata for the given id.
    #
    class GetImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          meta = vms.get_image(params[:id])
          uri  = meta[:location]

          store = Visor::API::Store.get_backend(uri, configs)
          store.file_exists?
        rescue NotFound => e
          return exit_error(404, e.message)
        rescue => e
          return exit_error(500, e.message)
        end

        EM.next_tick do
          store.get do |chunk|
            if chunk
              env.chunked_stream_send chunk
            else
              env.chunked_stream_close
            end
          end
        end

        custom_headers = {'Content-Type' => 'application/octet-stream',
                          'X-Stream'     => 'Goliath'}

        headers = push_meta_into_headers(meta, custom_headers)
        chunked_streaming_response(200, headers)
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
