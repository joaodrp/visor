require 'uri'

module Visor
  module Image

    # Visor Image System (VIS) Store module. This module encapsulates all store backend classes, plus a set of
    # utility methods common to all stores.
    #
    module Store
      extend self
      include Visor::Common::Exception

      # Base API mapping for the multiple storage backend classes
      BACKENDS = {:s3        => Visor::Image::Store::S3,
                  :cumulus   => Visor::Image::Store::Cumulus,
                  :walrus    => Visor::Image::Store::Walrus,
                  :lunacloud => Visor::Image::Store::Lunacloud,
                  :hdfs      => Visor::Image::Store::HDFS,
                  :file      => Visor::Image::Store::FileSystem,
                  :http      => Visor::Image::Store::HTTP}

      # Get a store backend class object ready to use, based on a file URI or store name.
      #
      # @param string [String] The file location URI or backend name.
      # @param config [Hash] A set of configurations for the wanted store, loaded from
      #   VISoR configuration file.
      #
      # @return [Object] An instantiated store object ready to use.
      #
      def get_backend(string, config)
        name  = URI(string).scheme || string
        store = BACKENDS[name.to_sym]
        raise UnsupportedStore, "The store '#{name}' is not supported" unless store
        store.new(string, config)
      end

    end
  end
end
