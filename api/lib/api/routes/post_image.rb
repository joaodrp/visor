module Visor
  module API

    # Post image data and metadata and returns the registered metadata.
    #
    class PostImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      # Pre-process headers as they arrive
      def on_headers(env, headers)
        @headers = headers
        @meta    = pull_meta_from_headers(headers)
      end

      # Pre-process body as it arrives in streaming chunks
      def on_body(env, data)
        @body ||= Tempfile.open('visor-image', encoding: 'ascii-8bit')
        @body << data
      end

      # Main method, processes and returns the request response
      def response(env)
        # only the x-image-meta-location header or the body content should be provided
        if @meta[:location] && @body
          msg = 'When x-image-meta-location header is present no file content can be provided'
          return exit_error(400, msg)
        end

        # first registers the image meta or raises on error
        begin
          insert_meta
        rescue ArgumentError => e
          @body.unlink if @body
          return exit_error(400, e.message)
        rescue InternalError => e
          @body.unlink if @body
          return exit_error(500, e.message)
        end

        # if has body(image file), upload file and update meta or raise on error
        begin
          upload_and_update
        rescue UnsupportedStore, ArgumentError => e
          return exit_error(400, e.message, true)
        rescue NotFound => e
          return exit_error(404, e.message, true)
        rescue InternalError => e
          return exit_error(500, e.message, true)
        ensure
          @body.unlink
        end unless @body.nil?

        [200, {}, {image: @meta}]
      end

      # Custom JSON error exit messages
      def exit_error(code, message, set_status=false)
        do_update(status: 'error') if set_status
        [code, {}, {code: code, message: message}]
      end

      # Insert image metadata on database (which set its status to locked)
      def insert_meta
        @meta = DB.post_image(@meta)
        @id   = @meta[:_id]
        do_update(status: 'available') if @meta[:location]
      end

      # Fire updates to image metadata on database
      def do_update(update)
        @meta = DB.put_image(@id, update)
      end

      # Update image status and launch upload
      def upload_and_update
        do_update(status: 'uploading')
        location, size, checksum = do_upload
        do_update(status: 'available', location: location, size: size, checksum: checksum)
      end

      # Upload image file to wanted store
      def do_upload
        content_type = @headers['Content-Type'] || ''
        store_name   = @meta[:store] || STORE_CONF[:default]
        format       = @meta[:format] || 'none'
        opts         = STORE_CONF[store_name.to_sym]

        unless content_type == 'application/octet-stream'
          raise ArgumentError, 'Request Content-Type must be application/octet-stream'
        end

        store = Visor::API::Store.get_backend(name: store_name)
        store.save(@id, @body, format, opts)
      end
    end

  end
end
