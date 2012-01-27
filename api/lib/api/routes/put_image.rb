require 'digest/md5'

module Visor
  module API

    # Put image metadata and/or data for the image with the given id.
    #
    class PutImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      # Pre-process headers as they arrive
      def on_headers(env, headers)
        env['headers'] = headers
      end

      # Pre-process body as it arrives in streaming chunks
      def on_body(env, data)
        env['body'] ||= Tempfile.open('visor-image', encoding: 'ascii-8bit')
        env['md5']  ||= Digest::MD5.new
        env['body'].write data
        env['md5'].update data
      end

      # Main method, processes and returns the request response
      def response(env)
        meta = pull_meta_from_headers(env['headers'])
        body = env['body']
        id   = params[:id]

        # a valid update requires the presence of headers and/or body
        if meta.empty? && body.nil?
          msg = 'No headers or body found for update'
          return exit_error(400, msg)
        end
        # only the x-image-meta-location header or the body content should be provided
        if meta[:location] && body
          msg = 'When x-image-meta-location header is present no file content can be provided'
          return exit_error(400, msg)
        end

        if meta[:store] == 'http' && body
          return exit_error(400, 'Cannot post an image file to a HTTP backend')
        end

        # first update the image meta or raises on error
        begin
          meta = update_meta(id, meta)
        rescue ArgumentError => e
          body.close if body
          body.unlink if body
          return exit_error(400, e.message)
        rescue InternalError => e
          body.close if body
          body.unlink if body
          return exit_error(500, e.message)
        end unless meta.empty?

        # if has body(image file), upload file and update meta or raise on error
        begin
          meta = upload_and_update(id, body)
        rescue UnsupportedStore, ArgumentError => e
          return exit_error(400, e.message, true)
        rescue NotFound => e
          return exit_error(404, e.message, true)
        rescue ConflictError => e
          return exit_error(409, e.message)
        rescue InternalError => e
          return exit_error(500, e.message, true)
        ensure
          body.close
          body.unlink
        end unless body.nil?

        [200, {}, {image: meta}]
      end

      # Custom JSON error exit messages
      def exit_error(code, message, set_status=false)
        do_update(params[:id], status: 'error') if set_status
        [code, {}, {code: code, message: message}]
      end

      # Update image metadata and set status if needed
      def update_meta(id, meta)
        meta = do_update(id, meta)
        do_update(id, status: 'available') if meta[:location]
      end

      # Fire updates to image metadata on database
      def do_update(id, update)
        DB.put_image(id, update)
      end

      # Update image status and launch upload
      def upload_and_update(id, body)
        meta     = DB.get_image(id)
        checksum = env['md5']
        raise ConflictError, 'Can only assign image file to a locked image' unless meta[:status]=='locked'
        meta           = do_update(id, status: 'uploading')
        location, size = do_upload(id, meta, body)
        do_update(id, status: 'available', location: location, size: size, checksum: checksum)
      end

      # Upload image file to wanted store
      def do_upload(id, meta, body)
        content_type = env['headers']['Content-Type'] || ''
        store_name   = meta[:store] || STORE_CONF[:default]
        format       = meta[:format] || 'none'
        config       = STORE_CONF[store_name.to_sym]

        unless content_type == 'application/octet-stream'
          raise ArgumentError, 'Request Content-Type must be application/octet-stream'
        end

        store = Visor::API::Store.get_backend(store_name, config)
        store.save(id, body, format)
      end
    end

  end
end
