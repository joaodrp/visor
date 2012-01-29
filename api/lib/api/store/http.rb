require "em-synchrony"
require "em-synchrony/em-http"

module Visor
  module API
    module Store

      # HTTP backend store
      #
      # 'http://www.domain.com/path-to-image-file'
      #
      # Useful for point an image to the last release of some distro, like:
      #
      # 'http://www.ubuntu.com/start-download?distro=server&bits=64&release=latest'
      #
      class HTTP
        include Visor::Common::Exception

        attr_accessor :uri, :config

        def initialize(uri, config=nil)
          @uri    = uri
          @config = config
        end

        def get
          http   = EventMachine::HttpRequest.new(uri).get
          finish = proc { yield nil }

          http.stream { |chunk| yield chunk }
          http.callback &finish
          http.errback &finish
        end

        def file_exists?(raise_exc=true)
          http = EventMachine::HttpRequest.new(uri, connect_timeout: 2, redirects: 5).head

          if location = http.response_header['LOCATION']
            http = EventMachine::HttpRequest.new(location, connect_timeout: 2).head
          end

          exist    = (http.response_header.status == 200)
          length   = http.response_header['CONTENT_LENGTH']
          size     = length.nil? ? nil : length.to_i
          etag     = http.response_header['ETAG']
          checksum = etag.nil? ? '' : etag.gsub('"', '')

          raise NotFound, "No image file found at #{uri}" if raise_exc && !exist
          [exist, size, checksum]
        end
      end

    end
  end
end
