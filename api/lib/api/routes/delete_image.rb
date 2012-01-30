module Visor
  module API

    # Delete the metadata and data of the image with the given id.
    #
    class DeleteImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, ['json', 'xml']

      def response(env)
        meta = vms.delete_image(params[:id])
        uri  = meta[:location]
        name = meta[:store]

        if uri && name
          store = Visor::API::Store.get_backend(uri, configs)
          store.delete unless name == 'http'
        end
      rescue NotFound => e
        exit_error(404, e.message)
      rescue Unauthorized => e
        exit_error(550, e.message)
      rescue => e
        exit_error(500, e.message)
      else
        [200, {}, {image: meta}]
      end

      def exit_error(code, message)
        logger.error message
        [code, {}, {code: code, message: message}]
      end
    end

  end
end
