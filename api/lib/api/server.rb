require 'goliath'
require 'json'

#require File.expand_path('../../api', __FILE__)

module Visor
  module API

    # Get brief information about all public images.
    #
    class GetImages < Goliath::API
      include Visor::Common::Exception
      use Goliath::Rack::Render, 'json'

      def response(env)
        begin
          images = db.get_public_images(true, params)
          [200, {}, {images: images}.to_json]
        rescue NotFound => e
          [404, {}, {code: 404, message: e.message}]
        end
      end
    end

    # The VISoR API Server. This supports all image metadata manipulation
    # operations, dispatched to the VISoR Meta Server and the image files storage operations.
    #
    class Server < Goliath::API

      use Goliath::Rack::Heartbeat
      use Goliath::Rack::Params
      use Goliath::Rack::Validation::RequestMethod, %w(GET HEAD POST PUT DELETE)

      # Get brief information about all public images.
      get '/images', GetImages

    end
  end
end
