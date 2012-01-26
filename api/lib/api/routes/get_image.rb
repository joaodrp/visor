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
          meta   = DB.get_image(params[:id])
          uri    = meta[:location]
          name   = meta[:store] || STORE_CONF[:default]
          config = STORE_CONF[name.to_sym]

          store = Visor::API::Store.get_backend(uri, config)
            #store.file_exists?
        rescue NotFound => e

          return [404, {}, {code: 404, message: e.message}]
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
    end

  end
end
