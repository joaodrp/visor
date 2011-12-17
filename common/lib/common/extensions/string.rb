module Visor
  module Common
    module Extensions
      #
      # Extending String class
      #
      module String
        # Convert string to Mongo oid
        def to_oid
          BSON::ObjectId self
        end
      end
    end
  end
end
String.send(:include, Visor::Common::Extensions::String)

