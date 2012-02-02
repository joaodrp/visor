require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Visor
  module API

    # The Client API for the VISoR API Server. This class supports all image metadata and
    # data manipulation operations through a programmatically interface.
    #
    # After Instantiate a Client object its possible to directly interact with the
    # api server and its store backends.
    #
    class Client

      include Visor::Common::Exception

      configs = Common::Config.load_config :visor_api

      DEFAULT_HOST = configs[:bind_host] || '0.0.0.0'
      DEFAULT_PORT = configs[:bind_port] || 4568

      attr_reader :host, :port, :format, :ssl

      # Initializes a new new VISoR API Client.
      #
      # @option opts [String] :host (DEFAULT_HOST) The host address where VISoR api server resides.
      # @option opts [String] :port (DEFAULT_PORT) The host port where VISoR api server resides.
      # @option opts [String] :format ('json') The format to render results ('json'/'xml').
      # @option opts [String] :ssl (false) If the connection should be made through HTTPS (SSL).
      #
      # @example Instantiate a client with default values:
      #   client = Visor::API::Client.new
      #
      # @example Instantiate a client with default values and SSL enabled:
      #   client = Visor::API::Client.new(ssl: true)
      #
      # @example Instantiate a client with custom host and port:
      #   client = Visor::API::Client.new(host: '127.0.0.1', port: 3000)
      #
      # @example Instantiate a client with XML rendering format:
      #   client = Visor::API::Client.new(format: 'xml')
      #
      def initialize(opts = {})
        @host   = opts[:host] || DEFAULT_HOST
        @port   = opts[:port] || DEFAULT_PORT
        @format = opts[:format] || 'json'
        @ssl    = opts[:ssl] || false
      end

      def get_images(query = {})
        str     = build_query(query)
        request = Net::HTTP::Get.new("/images#{str}")
        do_request(request)
      end


      protected

      def prepare_headers(request)
        request['User-Agent'] = 'VISoR API Server client'
        request['Accept']     = "application/#{format}"
        request['Content-Type'] = 'application/json' if ['POST', 'PUT'].include?(request.method)
      end

      def parse(response)
        result = JSON.parse(response.body, symbolize_names: true)
        result[:image] || result[:images] || result[:message]
      end

      def build_query(h)
        h.empty? ? '' : '?' + URI.encode_www_form(h)
      end

      def do_request(request)
        prepare_headers(request)

        begin
          response = Net::HTTP.new(host, port).request(request)
        rescue Exception => e
          raise ArgumentError, e.message
        end

        case response
        when Net::HTTPNotFound then
          raise NotFound, parse(response)
        when Net::HTTPBadRequest then
          raise Invalid, parse(response)
        when Net::HTTPConflict then
          raise ConflictError, parse(response)
        when Net::HTTPForbidden then
          raise Forbidden, parse(response)
        when Net::HTTPInternalServerError then
          raise InternalError, parse(response)
        else
          response.body
        end
      end

    end
  end
end
