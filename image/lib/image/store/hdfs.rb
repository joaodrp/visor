require 'uri'
require 'net/http'
require 'em-synchrony'
require 'em-synchrony/em-http'

module Visor
  module Image
    module Store

      # The Apache Hadoop HDFS (HDFS) backend store.
      #
      # This class handles the management of image files located in the HDFS storage system,
      # based on a URI like *hdfs://username@s<host>:<port>/<path>/<bucket>/<image>*.
      #
      #http://10.0.3.12:50075/webhdfs/v1/foo/1.iso?op=OPEN&user.name=hadoop&offset=0
      class HDFS
        include Visor::Common::Exception

        CONTEXT_ROOT="webhdfs/v1"

        attr_accessor :uri, :config, :username, :bucket, :file, :base, :host, :port

        # Initializes a new Cumulus store client object. Cumulus credentials are loaded from the URI,
        # on GET and DELETE operations, or from the configuration file for POST and PUT operation.
        #
        # @param [String] uri The URI of the file location.
        # @param config [Hash] A set of configurations for the wanted store, loaded from
        #   VISoR configuration file.
        #
        # @return [Object] An instantiated Cumulus store object ready to use.
        #
        def initialize(uri, config)
          @uri    = URI(uri)
          @config = config[:hdfs]

          if @uri.scheme
            @username = @uri.user
            @base     = @uri.path.split('/')[1..2].join('/')
            @bucket   = @uri.path.split('/')[3]
            @file     = @uri.path.split('/')[4]
            @host     = @uri.host
            @port     = @uri.port
          else
            @username = @config[:username]
            @bucket   = @config[:bucket]
            @base     = CONTEXT_ROOT
            @host     = @config[:host]
            @port     = @config[:port]
          end
        end


        # Returns the image file to clients, streamed in chunks.
        #
        # @return [Object] Yields the file, a chunk at time.
        #
        def get
          uri      = generate_uri('op=OPEN')
          # This raises cant yield from root fiber
          #res = EventMachine::HttpRequest.new(uri).get
          #url = URI(res.response_header['LOCATION'])
          #url.hostname = host
          #http   = EventMachine::HttpRequest.new(url).aget
          # ...

          # This works, should substitute (uri).get with (url).get in down
          #require "net/http"
          #req          = Net::HTTP::Get.new(uri.request_uri)
          #res          = Net::HTTP.new(uri.hostname, uri.port).request(req)
          #url          = URI(res['location'])
          #url.hostname = host
          #STDERR.puts "URL #{url}"
          # ...

          # This solves it by manually defining the final location (try to solve the error above)
          uri.port = 50075
          uri      = uri.to_s + '&offset=0'

          http   = EventMachine::HttpRequest.new(uri).aget
          finish = proc { yield nil }
          http.stream { |chunk| yield chunk }
          http.callback &finish
          http.errback &finish
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
          uri   = "hdfs://#{username}@#{host}:#{port}/#{base}/#{bucket}/#{file}"
          size  = tmp_file.size

          path     = generate_uri('op=CREATE&overwrite=true')
          http     = EventMachine::HttpRequest.new(path).put
          location = URI(http.response_header['LOCATION'])

          location.hostname = host
          #raise Duplicated, "The image file #{fp} already exists" if file_exists?(false)
          STDERR.puts "COPYING!!"

          EventMachine::HttpRequest.new(location).put :body => File.read(tmp_file)
          [uri, size]
        end

        # Deletes the image file from its location.
        #
        # @raise [NotFound] If the image file was not found.
        #
        def delete
          uri = generate_uri('op=DELETE&recursive=true')
          EventMachine::HttpRequest.new(uri).delete
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
          uri   = generate_uri('op=GETFILESTATUS')
          req   = Net::HTTP::Get.new(uri.request_uri)
          res   = Net::HTTP.new(uri.hostname, uri.port).request(req)
          exist = res.is_a? Net::HTTPSuccess
          raise NotFound, "No image file found at #{uri}" if raise_exc && !exist
          exist
        end

        def generate_uri(params)
          URI("http://#{host}:#{port}/#{base}/#{bucket}/#{file}?#{params}&user.name=#{username}")
        end
      end

    end
  end
end
