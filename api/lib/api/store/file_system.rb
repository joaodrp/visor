require 'uri'

module Visor
  module API
    module Store

      # FileSystem backend store
      #
      # 'file:///path/to/my_image.iso'
      #
      class FileSystem
        include Visor::Common::Exception

        CHUNKSIZE = 65536

        attr_accessor :uri, :fp, :config

        def initialize(uri, config)
          @uri    = URI(uri)
          @fp     = @uri.path
          @config = config[:file]
        end

        def get
          file_exists?
          open(fp, "rb") do |file|
            yield file.read(CHUNKSIZE) until file.eof?
            yield nil
          end
        end

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

        def delete
          file_exists?
          begin
            File.delete(fp)
          rescue => e
            raise Unauthorized, "Error while trying to delete image file #{fp}: #{e.message}"
          end
        end

        def file_exists?
          raise NotFound, "No image file found at #{fp}" unless File.exists?(fp)
        end

        private

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
