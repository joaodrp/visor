require 'uri'

module Visor
  module API
    module Store
      extend self
      include Visor::Common::Exception
      # Base API methods for the multiple storage backend classes
      #

      BACKENDS = {:file => Visor::API::Store::FileSystem}

      def get_backend(opts)
        name = URI(opts[:uri]).scheme rescue opts[:name]
        store = BACKENDS[name.to_sym]
        raise UnsupportedStore, "The store '#{store}' is not supported" unless store
        store
      end

      def file_exists?(uri)
        store = get_backend(uri: uri)
        store.file_exists?(uri)
      end

      def valid_backend?(name)
        store = BACKENDS[name.to_sym]
        raise UnsupportedStore, "The store '#{name}' is not supported" unless store
      end

    end
  end
end
