module Visor
  module API

    # Head metadata about the image with the given id.
    #
    class HeadImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      def response(env)
        meta   = vms.get_image(params[:id])
        header = push_meta_into_headers(meta)
        [200, header, nil]
      rescue NotFound => e
        exit_error(404, e.message)
      rescue => e
        exit_error(500, e.message)
      end

      def exit_error(code, message)
        logger.error message
        [code, {'x-error-code' => code.to_s, 'x-error-message' => message}, nil]
      end
    end

  end
end
