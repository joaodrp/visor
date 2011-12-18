module Visor
  module Common

    # The Module Extensions provides a set of functions to extend the Standard Core Libraries
    # with custom usefull methods used allong all VISoR sub-systems.
    #
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

