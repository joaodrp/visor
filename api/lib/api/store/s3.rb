require 'uri'
require "uber-s3"
require 'happening'
require "em-synchrony"
require "em-synchrony/em-http"

module Visor
  module API
    module Store

      # Amazon Simple Storage(S3) backend store
      #
      # 's3://access_key:secret_key@s3.amazonaws.com/bucket/my_image.iso'
      #
      class S3
        include Visor::Common::Exception

        CHUNKSIZE = 65536

        attr_accessor :uri, :fp

        def initialize(uri, config)
          @uri    = URI(uri)
          @config = config

          if @uri.scheme
            @access_key = @uri.user
            @secret_key = @uri.password
            @bucket     = @uri.path.split('/')[1]
            @file       = @uri.path.split('/')[2]
          else
            @access_key = @config[:access_key]
            @secret_key = @config[:secret_key]
            @bucket     = @config[:bucket]
          end
        end

        def get
          #file_exists?
          access_key = 'AKIAIABKOTWKSEXWTVXQ'
          secret_key = '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'
          bucket     = 'visor-images'
          image      = '1.iso'

          #item = Happening::S3::Item.new(bucket, image, {aws_access_key_id: access_key, aws_secret_access_key: secret_key})
          #item.get.stream do |chunk|
          #  yield chunk
          #end

          http       = EventMachine::HttpRequest.new('http://dl.dropbox.com/u/3528102/10.iso').aget
          finish     = proc { yield nil }
          http.stream { |chunk| yield chunk }
          http.callback &finish
          http.errback &finish
        end

        #def self.save(id, tmp_file, format, opts)
        #
        #  [uri, size]
        #end

        def delete

        end

        def file_exists?
          s3 = UberS3.new(:access_key => @access_key, :secret_access_key => @secret_key,
                          :bucket     => @bucket, :persistent => true, :adapter => :em_http_fibered)

          raise NotFound, "No image file found at #{@uri}" unless s3.exists?("/#{@file}")
        end


        #item = Happening::S3::Item.new(bucket, '2.iso',
        #                               :aws_access_key_id     => access_key,
        #                               :aws_secret_access_key => secret_key)
        #
        #item.put(File.read('/Users/joaodrp/1.iso')) do |response|
        #  puts "Upload finished!"; EM.stop
        #end
        #
        #item.get do |response|
        #  puts "the response content is: #{response.response}"
        #  EM.stop
        #end

        def parse_uri_credentials
          access_key = @uri.user
          secret_key = @uri.password
          bucket     = @uri.path.split('/')[1]
          image      = @uri.path.split('/')[2]

          [access_key, secret_key, bucket, image]
        end
      end

    end
  end
end
