require 'uri'
require 'digest/md5'
require "em-files"

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

          FileUtils.mkpath(dir) unless Dir.exists?(dir)
          raise Duplicated, "The image file #{fp} already exists" if File.exists?(fp)
          STDERR.puts "COPYING!!!!!!!!!!!!!!!!!!!!!!"

          #copy tempfile to the definitive file
          #open(tmp_file, "rb") do |tmp|
          #  open(fp, "wb") do |f|
          #    until tmp.eof?
          #      EM.next_tick do
          #        chunk = tmp.read(CHUNKSIZE)
          #        f << chunk
          #        md5.update chunk
          #      end
          #    end
          #  end
          #end

          tmp = File.open(tmp_file.path, "rb")
          new = File.open(fp, "wb")

          EM::File::write(new, tmp)

          #each_chunk(tmp, CHUNKSIZE) do |chunk|
          #  new << chunk
          #end

          [uri, size]
        end

        #def self.each_chunk(file, chunk_size=1024)
        #  yield file.read(chunk_size) until file.eof?
        #end

        def self.each_chunk(file, chunk_size=1024)
          handler = lambda do
            unless (file.eof?)
              yield file.read(chunk_size)
              EM.next_tick(&handler)
            end
          end
          EM.next_tick(&handler)
        end

        def self.delete(uri)
          fp = URI(uri).path
          raise NotFound, "No image file found at #{fp}" unless File.exists?(fp)
          begin
            File.delete(fp)
          rescue => e
            raise Unauthorized, "Error while trying to delete image file #{fp}: #{e.message}"
          end
        end

        def self.file_exists?(uri)
          fp = URI(uri).path
          raise NotFound, "No image file found at #{fp}" unless File.exists?(fp)
        end
      end

    end
  end
end
