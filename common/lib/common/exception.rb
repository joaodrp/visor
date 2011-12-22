module Visor
  module Common

    # The Exceptions module introduces a set of custom exceptions used allong
    # all VISoR sub-systems.
    #
    module Exception

      # raise if invalid data is provided within new metadata
      class Invalid < ArgumentError;
      end

      # raise if no image meta is found
      class NotFound < StandardError;
      end

      # raise on a configuration error
      class ConfigError < RuntimeError;
      end
    end
  end
end
