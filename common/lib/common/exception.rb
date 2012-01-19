module Visor
  module Common

    # The Exceptions module introduces a set of custom exceptions used along
    # all VISoR sub-systems.
    #
    module Exception

      # Raise if invalid data is provided within new metadata
      class Invalid < ArgumentError; end

      # Raise if no image meta or file path is not found
      class NotFound < StandardError; end

      # Raise on a configuration error
      class ConfigError < RuntimeError; end

      # Raise if provided store backend is not supported
      class UnsupportedStore < RuntimeError; end

      # Raise if a record or file is already stored
      class Duplicated < RuntimeError; end

      # Raise on an internal server error
      class InternalError < RuntimeError; end

      # Raise on error trying to manipulate image files
      class Unauthorized < RuntimeError; end

      # Raise on error trying to update image files/meta
      class ConflictError < RuntimeError; end
    end
  end
end
