module Visor
  module Common

    # The Module Extensions provides a set of functions to extend the Standard Core Libraries
    # with custom usefull methods used allong all VISoR sub-systems.
    #
    module Extensions
      #
      # Extending YAML library
      #
      module YAML

        # Load a YAML source to to an OpenStruct object.
        # Used for Hash.to_openstruct
        #
        # @param source [YAML] A file or a parsed YAML object.
        #
        # @return [OpenStruct] YAML file parsed to an OpenStruct object.
        #
        def self.load_openstruct(source)
          self.load(source).to_openstruct
        end

      end
    end
  end
end

YAML.send :include, Visor::Common::Extensions::YAML
