module Visor
  module Common

    # The Module Extensions provides a set of functions to extend the Standard Core Libraries
    # with custom usefull methods used allong all VISoR sub-systems.
    #
    module Extensions
      #
      # Extending Object class
      #
      module Object

        # Pass from Hash.to_openstruct
        #
        # @return [self] The object itself.
        #
        def to_openstruct
          self
        end

      end
    end
  end
end

Object.send :include, Visor::Common::Extensions::Object

