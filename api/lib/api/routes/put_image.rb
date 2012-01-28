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
        (env['body'] ||= Tempfile.open('visor-image', encoding: 'ascii-8bit')) << data
        (env['md5'] ||= Digest::MD5.new) << data
      end

      # Main method, processes and returns the request response
      def response(env)
        meta     = pull_meta_from_headers(env['headers'])
        body     = env['body']
        id       = params[:id]
        location = meta[:location]

        # a valid update requires the presence of headers and/or body
        if meta.empty? && body.nil?
          msg = 'No headers or body found for update'
          return exit_error(400, msg)
        end
        # only the x-image-meta-location header or the body content should be provided
        if location && body
          msg = 'When the location header is present no file content can be provided'
          return exit_error(400, msg)
        end

        if meta[:store] == 'http' || (location && location.split(':').first == 'http')
          return exit_error(400, 'Cannot post an image file to a HTTP backend') if body
          store = Visor::API::Store::HTTP.new(location)

          exist, meta[:size], meta[:checksum] = store.file_exists?(false)
          return exit_error(404, "No image file found at #{location}") unless exist
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
        rescue Duplicated => e
          return exit_error(409, e.message, true)
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
        logger.error message
        begin
          vms.put_image(params[:id], status: 'error') if set_status
        rescue => e
          logger.error "Unable to set image #{env['id']} status to 'error': #{e.message}"
        end
        [code, {}, {code: code, message: message}]
      end

      # Update image metadata and set status if needed
      def update_meta(id, meta)
        logger.debug "Updating image #{id} meta:"
        meta = vms.post_image(id, meta)
        meta.each { |k, v| logger.debug "#{k.to_s.capitalize} setted to #{v}" }

        if meta[:location]
          logger.debug "Location for image #{env['id']} is #{meta[:location]}"
          logger.debug "Setting image #{env['id']} status to 'available'"
          vms.put_image(id, status: 'available')
        end
      end

      # Update image status and launch upload
      def upload_and_update(id, body)
        meta     = vms.get_image(id)
        checksum = env['md5']
        raise ConflictError, 'Can only assign image file to a locked image' unless meta[:status]=='locked'

        logger.debug "Setting image #{id} status to 'uploading'"
        meta           = vms.put_image(id, status: 'uploading')
        location, size = do_upload(id, meta, body)

        logger.debug "Updating image #{id} meta:"
        logger.debug "Setting status to 'available'"
        logger.debug "Setting location to '#{location}'"
        logger.debug "Setting size to '#{size}'"
        logger.debug "Setting checksum to '#{checksum}'"
        vms.post_image(id, status: 'available', location: location, size: size, checksum: checksum)
      end

      # Upload image file to wanted store
      def do_upload(id, meta, body)
        content_type = env['headers']['Content-Type'] || ''
        store_name   = meta[:store] || configs[:default]
        format       = meta[:format] || 'none'

        unless content_type == 'application/octet-stream'
          raise ArgumentError, 'Request Content-Type must be application/octet-stream'
        end

        store = Visor::API::Store.get_backend(store_name, configs)
        logger.debug "Uploading image #{id} data to #{store_name} store"
        store.save(id, body, format)
      end
    end

  end
end
