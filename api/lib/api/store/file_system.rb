require 'uri'

module Visor
  module API
    module Store

      # The FileSystem backend store.
      #
      # This class handles the management of image files located in the local FileSystem,
      # based on a URI like *file:///path/to/my_image.format*.
      #
      class FileSystem
        include Visor::Common::Exception

        # Size of the chunk to stream the files out.
        CHUNKSIZE = 65536

        attr_accessor :uri, :fp, :config

        # Initializes a new FileSystem store client object.
        #
        # @param [String] uri The URI of the file location.
        # @param config [Hash] A set of configurations for the wanted store, loaded from
        #   VISoR configuration file.
        #
        # @return [Object] An instantiated FileSystem store object ready to use.
        #
        def initialize(uri, config)
          @uri    = URI(uri)
          @fp     = @uri.path
          @config = config[:file]
        end

        # Returns the image file to clients, streamed in chunks.
        #
        # @return [Object] Yields the file, a chunk at time.
        #
        def get
          file_exists?
          open(fp, "rb") do |file|
            yield file.read(CHUNKSIZE) until file.eof?
            yield nil
          end
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
          dir  = File.expand_path config[:directory]
          file = "#{id}.#{format}"
          fp   = File.join(dir, file)
          uri  = "file://#{fp}"
          size = tmp_file.size

          FileUtils.mkpath(dir) unless Dir.exists?(dir)
          raise Duplicated, "The image file #{fp} already exists" if File.exists?(fp)
          STDERR.puts "Copying image tempfile #{tmp_file.path} to definitive #{fp}"

          tmp = File.open(tmp_file.path, "rb")
          new = File.open(fp, "wb")

          each_chunk(tmp, CHUNKSIZE) do |chunk|
            new << chunk
          end

          [uri, size]
        end

        # Deletes the image file to from its location.
        #
        # @raise [Forbidden] If user does not have permission to manipulate the image file.
        # @raise [NotFound] If the image file was not found.
        #
        def delete
          file_exists?
          begin
            File.delete(fp)
          rescue => e
            raise Forbidden, "Error while trying to delete image file #{fp}: #{e.message}"
          end
        end

        # Check if the image file exists.
        #
        # @raise [NotFound] If the image file was not found.
        #
        def file_exists?
          raise NotFound, "No image file found at #{fp}" unless File.exists?(fp)
        end

        private

        # Iterates over the image file yielding a chunk per reactor tick.
        #
        # @return [Object] Yielded image file chunk.
        #
        def each_chunk(file, chunk_size=CHUNKSIZE)
          handler = lambda do
            unless file.eof?
              yield file.read(chunk_size)
              EM.next_tick &handler
            end
          end
          EM.next_tick &handler
        end

      end
    end
  end
end
