require "em-synchrony"
require "em-synchrony/em-http"

module Visor
  module Image
    module Store

      # The HTTP backend store.
      #
      # This class handles the management of image files located in a remote HTTP location,
      # based on a URI like *'http://www.domain.com/path-to-image-file'*.
      #
      # Useful for point an image to the last release of some distro, like:
      #   'http://www.ubuntu.com/start-download?distro=server&bits=64&release=latest'
      #
      class HTTP
        include Visor::Common::Exception

        attr_accessor :uri, :config

        # Initializes a new HTTP store client object.
        #
        # @param [String] uri The URI of the file location.
        # @param [Hash] config (nil) A set of configurations for the wanted store,
        #   loaded from VISoR configuration file.
        #
        # @return [Object] An instantiated HTTP store object ready to use.
        #
        def initialize(uri, config=nil)
          @uri    = uri
          @config = config
        end

        # Returns the image file to clients, streamed in chunks.
        #
        # @return [Object] Yields the file, a chunk at time.
        #
        def get
          http   = EventMachine::HttpRequest.new(uri).aget
          finish = proc { yield nil }

          http.stream { |chunk| yield chunk }
          http.callback &finish
          http.errback &finish
        end

        # Check if the image file exists. This will follow redirection to a
        # nested deepness of 5 levels. It will also try to follow the location header
        # if any.
        #
        # Also, after finding the real location of the HTTP file, it will parse the file
        # metadata, most properly the size and checksum, based on URL headers.
        #
        # @return [String] The discovered file checksum and size.
        #
        # @raise [NotFound] If the image file was not found.
        #
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
