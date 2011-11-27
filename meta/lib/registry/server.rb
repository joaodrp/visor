require 'sinatra/base'
require File.dirname(__FILE__) + '/../../lib/registry'

module Cbolt
  module Registry
    class Server < Sinatra::Base

      before do
        @db = Cbolt::Backends::MongoDB.new
      end

      # Get brief information about all public images
      #
      # [{ '_id':<_id>,
      #    'name':<name>,
      #    'architecture':<architecture>,
      #    'type':<type>,
      #    'format':<format>,
      #    'store':<type>
      #  }, ...]
      #
      get '/' do
        begin
          images = @db.get_public_images(true)
          images.to_json
        rescue => e
          error 400, e.message.to_json
        end
      end

      # Get detailed information about all public images
      #
      # [{ '_id':<_id>,
      #    'uri':<uri>,
      #    'name':<name>,
      #    'architecture':<architecture>,
      #    'access':<access>,
      #    'status':<status>,
      #    'size':<size>,
      #    'type':<type>,
      #    'format':<format>,
      #    'store':<type>,
      #    'updated_at':<updated_at>,
      #    'others':<others>
      #  }, ...]
      #
      get '/images' do
        begin
          images = @db.get_public_images
          images.to_json
        rescue
          error 400, e.message.to_json
        end
      end

      # Get detailed information about a specific image
      #
      # { '_id':<_id>,
      #    'uri':<uri>,
      #    'name':<name>,
      #    'architecture':<architecture>,
      #    'access':<access>,
      #    'status':<status>,
      #    'size':<size>,
      #    'type':<type>,
      #    'format':<format>,
      #    'store':<type>,
      #    'updated_at':<updated_at>,
      #    'others':<others>
      # }
      #
      get '/images/:id' do
        begin
          res = @db.get_image(params[:id])
          res.to_json
        rescue => e
          error 400, e.message.to_json
        end
      end

      run! if app_file == $0

    end
  end
end

#Server.run!
