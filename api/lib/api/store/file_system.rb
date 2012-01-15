class File
  def each_chunk(chunk_size=1024*1024)
    yield read(chunk_size) until eof?
  end
end

require 'uri'

module Visor
  module API
    module Store
      # FileSystem backend store
      #
      # 'file:///path/to/my_file.iso'
      #
      class FileSystem
        CHUNKSIZE = 65536

        def initialize(uri)
          @uri  = uri
          @path = uri.path
        end

        def get
          raise "No image file found at #{@path}" unless File.exists?(@path)

          open(@path, "rb") do |file|
            file.each_chunk(CHUNKSIZE) { |chunk| yield chunk }
          end
        end
      end

    end
  end
end
