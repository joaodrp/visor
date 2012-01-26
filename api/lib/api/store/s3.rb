require 'uri'
require "uber-s3"
require 'happening'
require "em-synchrony"
require "em-synchrony/em-http"

module Happening
  module S3
    class Request
      VALID_HTTP_METHODS = [:head, :ahead, :get, :aget, :put, :delete]
    end

    class Item
      def aget(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("GET", path) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:aget, url, {:ssl => options[:ssl]}.update(request_options)).execute
      end

      def head(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("HEAD", path) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:head, url, {:ssl => options[:ssl]}.update(request_options)).execute
      end

      def ahead(request_options = {}, &blk)
        headers = needs_to_sign? ? aws.sign("HEAD", path) : {}
        request_options[:on_success] = blk if blk
        request_options.update(:headers => headers)
        Happening::S3::Request.new(:ahead, url, {:ssl => options[:ssl]}.update(request_options)).execute
      end
    end
  end
end

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

        def credentials
          {aws_access_key_id: @access_key, aws_secret_access_key: @secret_key}
        end

        def get
          s3     = Happening::S3::Item.new(@bucket, @file, credentials).aget
          finish = proc { yield nil }

          s3.stream { |chunk| yield chunk }
          s3.callback &finish
          s3.errback &finish
        end

        def save(id, tmp_file, format)
          @file = "#{id}.#{format}"
          uri   = "s3://#{@access_key}:#{@secret_key}@s3.amazonaws.com/#{@bucket}/#{@file}"
          size  = tmp_file.size

          raise Duplicated, "The image file #{fp} already exists" if file_exists?(false)
          STDERR.puts "COPYING!!"

          s3 = Happening::S3::Item.new(@bucket, @file, credentials)
          s3.put(File.read(tmp_file))
          #http.callback &finish
          #http.errback &finish

          [uri, size]
        end

        def delete
          s3 = Happening::S3::Item.new(@bucket, @file, credentials)
          s3.delete
        end

        def file_exists?(raise_exc=true)
          s3 = UberS3.new(:access_key => @access_key, :secret_access_key => @secret_key,
                          :bucket     => @bucket, :persistent => true, :adapter => :em_http_fibered)

          exist = s3.exists?("/#{@file}")
          raise NotFound, "No image file found at #{@uri}" if raise_exc && !exist
          exist
        end
      end

    end
  end
end
