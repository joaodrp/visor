require 'uri'
require 'digest/md5'

module Visor
  module API
    module Store
      # FileSystem backend store
      #
      # 'file:///path/to/my_file.iso'
      #
      class FileSystem
        include Visor::Common::Exception

        CHUNKSIZE = 65536

        def self.get(uri)
          path = URI(uri).path
          open(path, "rb") do |file|
            yield file.read(CHUNKSIZE) until file.eof?
          end
        end

        def self.save(id, tmp_file, format, opts)
          dir  = File.expand_path opts[:directory]
          file = "#{id}.#{format}"
          fp   = File.join(dir, file)
          uri  = "file://#{fp}"
          size = tmp_file.size
          md5  = Digest::MD5.new

          FileUtils.mkpath(dir) unless Dir.exists?(dir)
          raise Duplicated, "The image file #{fp} already exists" if File.exists?(fp)
          # copy tempfile to the definitive file
          open(tmp_file, "rb") do |tmp|
            open(fp, "wb") do |f|
              until tmp.eof?
                chunk = tmp.read(CHUNKSIZE)
                f << chunk
                md5.update chunk
              end
            end
          end
          [uri, size, md5.hexdigest]
        end

        def self.file_exists?(uri)
          path = URI(uri).path
          raise NotFound, "No image file found at #{path}" unless File.exists?(path)
        end
      end

    end
  end
end
