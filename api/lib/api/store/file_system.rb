require 'uri'

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

        def initialize(uri)
          @uri  = uri
          @path = uri.path
        end

        def get
          open(@path, "rb") do |file|
            yield file.read(CHUNKSIZE) until file.eof?
          end
        end


        def file_exists?
          raise NotFound, "No image file found at #{@path}" unless File.exists?(@path)
        end
      end

    end
  end
end
