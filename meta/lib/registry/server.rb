require 'sinatra/base'
require File.expand_path '../../registry', __FILE__

module Cbolt
  module Registry
    class Server < Sinatra::Base
      # TODO: Pass/retrieve metadata from GET/images/:id, POST and PUT in HTTP HEADERS so image can be further passed simultaniously throught BODY
      # TODO: Rethink error handing, status codes, content-type and / and /images to /index or HEAD
      # http://glance.openstack.org/glanceapi.html
      # http://www.sinatrarb.com/intro

      #configure :development do
      #  require 'sinatra/reloader'
      #  register Sinatra::Reloader
      #end

      include Cbolt::Registry::Backends

      DB = MongoDB.connect

      # Filters
      # Configure database connection and JSON parsing options
      before do
        @parse_opts = {symbolize_names: true}
        content_type :json
      end

      # Routes
      #

      # @method get_all_brief
      # @overload get '/'
      #
      # Get brief information about all public images.
      #
      #   { "images": [{
      #       "_id"":<_id>,
      #       "name":<name>,
      #       "architecture":<architecture>,
      #       "type":<type>,
      #       "format":<format>,
      #       "store":<type>
      #       }, ...]}
      #
      # @param [String] Any available field values can be passed as query parameters,
      #   plus the sort=<attribute> and dir=<asc/desc> parameters.
      #
      # @return [JSON] The public images brief metadata.
      #
      # @raise [HTTP Error 404] If there is no public images.
      #
      get '/' do
        begin
          images = DB.get_public_images(true, params)
          {images: images}.to_json
        rescue => e
          error 404, e.message.to_json
        end
      end

      # @method get_all_detail
      # @overload get '/images'
      #
      # Get detailed information about all public images.
      #
      #   {"images": [{
      #       "_id":<_id>,
      #       "uri":<uri>,
      #       "name":<name>,
      #       "architecture":<architecture>,
      #       "access":<access>,
      #       "status":<status>,
      #       "size":<size>,
      #       "type":<type>,
      #       "format":<format>,
      #       "store":<type>,
      #       "updated_at":<updated_at>,
      #       "others":<others>
      #       }, ...]}
      #
      # @param [String] Any available field values can be passed as query parameters,
      #   plus the sort=<attribute> and dir=<asc/desc> parameters.
      #
      # @return [JSON] The public images detailed metadata.
      #
      # @raise [HTTP Error 404] If there is no public images.
      #
      get '/images' do
        begin
          images = DB.get_public_images(false, params)
          {images: images}.to_json
        rescue
          error 404, e.message.to_json
        end
      end

      # @method get_detail
      # @overload get '/images/:id'
      #
      # Get detailed information about a specific image.
      #
      #   {"images": {
      #       "_id":<_id>,
      #       "uri":<uri>,
      #       "name":<name>,
      #       "architecture":<architecture>,
      #       "access":<access>,
      #       "status":<status>,
      #       "size":<size>,
      #       "type":<type>,
      #       "format":<format>,
      #       "store":<type>,
      #       "updated_at":<updated_at>,
      #       "others":<others>
      #   }}
      #
      # @param [Integer] id The wanted image id.
      #
      # @return [JSON] The image detailed metadata.
      #
      # @raise [HTTP Error 404] If image not found.
      #
      get '/images/:id' do |id|
        content_type :json
        begin
          image = DB.get_image(id)
          {image: image}.to_json
        rescue => e
          error 404, e.message.to_json
        end
      end

      # @method post
      # @overload post '/images'
      #
      # Create a new image metadata and returns it.
      #
      # @param [JSON] The image metadata.
      #
      # @return [JSON] The image detailed metadata.
      #
      # @raise [HTTP Error 400] Image metadata validation errors.
      #
      post '/images' do
        begin
          meta = JSON.parse(request.body.read, @parse_opts)
          id = DB.post_image(meta[:image])
          image = DB.get_image(id)
          {image: image}.to_json
        rescue => e
          error 400, e.message.to_json
        end
      end

      # @method put
      # @overload put '/images/:id'
      #
      # Update an existing image metadata and return it.
      #
      # @param [Integer] id The wanted image id.
      # @param [JSON] The image metadata update.
      #
      # @return [JSON] The image detailed metadata.
      #
      # @raise [HTTP Error 400] Image metadata update validation errors.
      #
      put '/images/:id' do |id|
        begin
          meta = JSON.parse(request.body.read, @parse_opts)
          image = DB.put_image(id, meta[:image])
          {image: image}.to_json
        rescue => e
          error 400, e.message.to_json
        end
      end

      # @method delete
      # @overload delete '/images/:id'
      #
      # Delete an image metadata and return it.
      #
      # @param [Integer] id The image id to delete.
      #
      # @return [JSON] The image detailed metadata.
      #
      # @raise [HTTP Error 404] If image not found.
      #
      delete '/images/:id' do
        begin
          image = DB.delete_image(params[:id])
          {image: image}.to_json
        rescue => e
          error 404, e.message.to_json
        end
      end
    end
  end
end

Cbolt::Registry::Server.run! port: 3000, environment: :production if __FILE__ == $0


