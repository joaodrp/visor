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
        schema = uri.scheme
        store  = BACKENDS[schema.to_sym]
        raise UnsupportedStore, "The store '#{store}' is not supported" unless store
        store
      end

      def self.get(uri)
        parsed = URI.parse(uri)
        klass  = get_backend(parsed)
        store  = klass.new(parsed)
        store.get { |chunk| yield chunk }
      end

    end
  end
end
