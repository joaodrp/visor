require 'uri'

module Visor
  module API
    module Store

      #TODO: logging
      include Visor::Common::Exception

      # Base API class for the multiple storage backend classes
      #
      BACKENDS = {:file => FileSystem}

      def self.get_backend(uri)
        parsed = URI.parse(uri)
        store = BACKENDS[parsed.scheme.to_sym]
        raise UnsupportedStore, "The store '#{store}' is not supported" unless store
        store.new(parsed)
      end

      def self.get(uri)
        store = get_backend(uri)
        store.get { |chunk| yield chunk }
      end

      def self.file_exists?(uri)
        store = get_backend(uri)
        store.file_exists?
      end

    end
  end
end
