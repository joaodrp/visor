module Visor
  module Common

    # The Module Extensions provides a set of functions to extend the Standard Core Libraries
    # with custom usefull methods used allong all VISoR sub-systems.
    #
    module Extensions
      #
      # Extending Array class
      #
      module Array

        # Convert each array element to an OpenStruct.
        # Used for Hash.to_openstruct
        #
        # @return [Array] The array with elements converted to OpenStruct.
        #
        def to_openstruct
          map { |el| el.to_openstruct }
        end

      end
    end
  end
end

Array.send :include, Visor::Common::Extensions::Array
