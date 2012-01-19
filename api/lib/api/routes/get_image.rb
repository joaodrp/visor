module Visor
  module API

    # Get image data and metadata for the given id.
    #
    class GetImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      def default_headers
        {'Content-Type' => 'application/octet-stream',
         'X-Stream'     => 'Goliath'}
      end

      def response(env)
        begin
          meta = DB.get_image(params[:id])
          uri  = meta[:location]
          Visor::API::Store.file_exists?(uri)
        rescue NotFound => e
          return [404, {}, {code: 404, message: e.message}]
        end

        store = Visor::API::Store.get_backend(uri: uri)

        operation = proc do
          store.get(uri) { |chunk| env.stream_send chunk }
        end

        callback = proc { env.stream_close }
        EM.defer operation, callback

        headers = push_meta_into_headers(meta, default_headers)
        [200, headers, Goliath::Response::STREAMING]
      end
    end

  end
end
