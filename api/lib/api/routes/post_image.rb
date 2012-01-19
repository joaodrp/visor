module Visor
  module API

    # Post image data and metadata and returns the registered metadata.
    #
    class PostImage < Goliath::API
      include Visor::Common::Exception
      include Visor::Common::Util
      use Goliath::Rack::Render, 'json'

      def exit_error(code, message)
        [code, {}, {code: code, message: message}]
      end

      def insert_meta
        @meta = DB.post_image(@meta)
        @id   = @meta[:_id]
        update_meta(status: 'available')
      end

      def update_meta(update)
        DB.put_image(@id, update)
      end

      def update_status_and_upload
        @meta = update_meta(status: 'uploading')
        location, size, checksum = upload_image_file
        @meta = update_meta(status: 'available', location: location, size: size, checksum: checksum)
      end

      def upload_image_file
        content_type = @headers['Content-Type'] || ''
        store_name   = @meta[:store] || STORE_CONF[:default]
        format       = @meta[:format] || 'none'
        opts         = STORE_CONF[store_name.to_sym]

        unless content_type == 'application/octet-stream'
          update_meta(status: 'error')
          raise ArgumentError, 'Request Content-Type must be application/octet-stream'
        end

        store = Visor::API::Store.get_backend(name: store_name)
        update_meta(status: 'uploading')
        store.save(@id, @body, format, opts)
      end

      def on_headers(env, headers)
        @headers = headers
        @meta    = pull_meta_from_headers(headers)
      end

      def on_body(env, data)
        @body ||= Tempfile.open('visor-image', '~/tmp', encoding: 'ascii-8bit')
        @body << data
      end

      def response(env)
        # only the x-image-meta-location header or the body
        # content should be provided
        if @meta.include?(:location) && @body
          msg = 'x-image-meta-location header is present, no body file content can be provided'
          return exit_error(400, msg)
        end

        begin
          # first registers the image meta
          # or raises on error
          insert_meta
        rescue ArgumentError => e
          @body.unlink if @body
          return exit_error(400, e.message)
        rescue InternalError => e
          @body.unlink if @body
          return exit_error(500, e.message)
        end

        begin
          # then, if there is a body(image file), upload image and
          # update meta or raise on error
          update_status_and_upload
        rescue UnsupportedStore, ArgumentError => e
          return exit_error(400, e.message)
        rescue NotFound => e
          return exit_error(404, e.message)
        rescue InternalError => e
          return exit_error(500, e.message)
        ensure
          @body.unlink
        end unless @body.nil?

        [200, {}, {image: @meta}]
      end
    end

  end
end
