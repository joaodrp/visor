require 'uri'

module Visor
  module API
    module Store
      extend self
      include Visor::Common::Exception

      # Base API methods for the multiple storage backend classes
      #
      BACKENDS = {:file => Visor::API::Store::FileSystem,
                  :s3   => Visor::API::Store::S3}

      def get_backend(uri, config)
        name  = URI(uri).scheme || uri
        store = BACKENDS[name.to_sym]
        raise UnsupportedStore, "The store '#{store}' is not supported" unless store
        store.new(uri, config)
      end

      def valid_backend?(name)
        store = BACKENDS[name.to_sym]
        raise UnsupportedStore, "The store '#{name}' is not supported" unless store
      end

    end
  end
end
