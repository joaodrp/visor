require 'uri'
require 'happening'

module Visor
  module Image
    module Store

      # The Amazon Simple Storage (S3) backend store.
      #
      # This class handles the management of image files located in the S3 storage system,
      # based on a URI like *s3://<access_key>:<secret_key@s3.amazonaws.com/<bucket>/<image>*.
      #
      class S3
        include Visor::Common::Exception

        attr_accessor :uri, :config, :access_key, :secret_key, :bucket, :file

        # Initializes a new S3 store client object. S3 credentials are loaded from the URI,
        # on GET and DELETE operations, or from the configuration file for POST and PUT operation.
        #
        # @param [String] uri The URI of the file location.
        # @param config [Hash] A set of configurations for the wanted store, loaded from
        #   VISoR configuration file.
        #
        # @return [Object] An instantiated S3 store object ready to use.
        #
        def initialize(uri, config)
          @uri    = URI(uri)
          @config = config[:s3]

          if @uri.scheme
            @access_key = @uri.user
            @secret_key = @uri.password
            @bucket     = @uri.path.split('/')[1]
            @file       = @uri.path.split('/')[2]
          else
            @access_key = @config[:access_key]
            @secret_key = @config[:secret_key]
            @bucket     = @config[:bucket]
          end
        end

        # Returns a Happening library S3 connection object.
        #
        # @return [Happening::S3::Item] A new S3 connection object.
        #
        def connection
          Happening::S3::Item.new(bucket, file, aws_access_key_id: access_key, aws_secret_access_key: secret_key)
        end

        # Returns the image file to clients, streamed in chunks.
        #
        # @return [Object] Yields the file, a chunk at time.
        #
        def get
          s3     = connection.aget
          finish = proc { yield nil }

          s3.stream { |chunk| yield chunk }
          s3.callback &finish
          s3.errback &finish
        end

        # Saves the image file to the its final destination, based on the temporary file
        # created by the server at data reception time.
        #
        # @param [String] id The image id.
        # @param [File] tmp_file The temporary file descriptor.
        # @param [String] format The image file format.
        #
        # @return [String, Integer] The generated file location URI and image file size.
        #
        # @raise [Duplicated] If the image file already exists.
        #
        def save(id, tmp_file, format)
          @file = "#{id}.#{format}"
          uri   = "s3://#{access_key}:#{secret_key}@s3.amazonaws.com/#{bucket}/#{file}"
          size  = tmp_file.size

          raise Duplicated, "The image file #{fp} already exists" if file_exists?(false)
          STDERR.puts "COPYING!!"

          connection.put(File.read(tmp_file))

          [uri, size]
        end

        # Deletes the image file from its location.
        #
        # @raise [NotFound] If the image file was not found.
        #
        def delete
          connection.delete
        end

        # Check if the image file exists.
        #
        # @param [True, False] raise_exc (true) If it should raise exception or return
        #   true/false whether the file exists or not.
        #
        # @return [True, False] If raise_exc is false, return true/false whether the
        #   file exists or not.
        #
        # @raise [NotFound] If the image file was not found.
        #
        def file_exists?(raise_exc=true)
          exist   = nil
          error   = proc { exist = false }
          success = proc { |res| exist = true if res.response_header.status == 200 }

          connection.head(on_error: error, on_success: success)
          raise NotFound, "No image file found at #{uri}" if raise_exc && !exist
          exist
        end
      end

    end
  end
end
