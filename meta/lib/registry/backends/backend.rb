module Cbolt
  module Backends
    class Backend
      # TODO: convert passed-in fields to their proper type (ex: convert size to Long)
      # TODO: order fields in hashes?

      # Keys validation
      #
      # Mandatory attributes
      MANDATORY    = [:name, :architecture, :access]
      # Read-only attributes
      READONLY     = [:_id, :uri, :owner, :status, :size, :created_at, :uploaded_at,
                      :updated_at, :accessed_at, :access_count, :checksum]
      # Optional attributes
      OPTIONAL     = [:type, :format, :store]
      # All attributes
      ALL          = MANDATORY + OPTIONAL + READONLY

      # Values validation
      #
      # Architecture options
      ARCHITECTURE = %w[i386 x86_64]
      # Access options
      ACCESS       = %w[public private]
      # Possible disk formats
      FORMAT       = %w[none iso vhd vdi vmdk ami aki ari]
      # Possible types
      TYPE         = %w[none kernel ramdisk amazon eucalyptus openstack opennebula nimbus]
      # Possible status
      STATUS       = %w[locked uploading error available]
      # Possible storages
      STORE        = %w[s3 swift cumulus hdfs fs]

      # Presentation options
      #
      # Brief attributes used to return only brief information about images.
      BRIEF        = [:_id, :name, :architecture, :type, :format, :store, :size]
      # Attributes to exclude from get public images requests, allowing to show other custom attributes.
      DETAIL_EXC   = [:owner, :created_at, :uploaded_at, :accessed_at, :access_count, :checksum]
      # Valid parameters to filter results from requests query, add sort parameter and sort direction.
      FILTERS = ALL + [:sort, :dir]

      attr_reader :db, :host, :port

      # Initializes a Backend instance.
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :db The wanted database.
      # @option opts [String] :host The host address.
      # @option opts [Integer] :port The port to be used.
      #
      def initialize(db, host, port)
        @db   = db
        @host = host
        @port = port
      end

      # Validates the image metadata for a post operation, based on possible keys and values.
      #
      # @param [Hash] meta The image metadata.
      #
      # @raise[ArgumentError] If some of the metadata fields do not respect the
      #   possible values, contains any read-only or misses any mandatory field.
      #
      def validate_data_post(meta)
        meta.assert_exclusion_keys(READONLY)
        meta.assert_inclusion_keys(MANDATORY)

        meta.assert_valid_values_for(:architecture, ARCHITECTURE)
        meta.assert_valid_values_for(:access, ACCESS)
        meta.assert_valid_values_for(:format, FORMAT)
        meta.assert_valid_values_for(:type, TYPE)
        meta.assert_valid_values_for(:store, STORE)

        assert_ramdisk_and_kernel_image(meta)

        meta.set_blank_keys_value_to(BRIEF, [:_id], nil)
      end

      # Validates the image metadata for a put operation, based on possible keys and values.
      #
      # @param [Hash] meta The image metadata.
      #
      # @raise[ArgumentError] If some of the metadata fields do not respect the
      #   possible values, contains any read-only or misses any mandatory field.
      #
      def validate_data_put(meta)
        meta.assert_exclusion_keys(READONLY)

        meta.assert_valid_values_for(:architecture, ARCHITECTURE)
        meta.assert_valid_values_for(:access, ACCESS)
        meta.assert_valid_values_for(:format, FORMAT)
        meta.assert_valid_values_for(:type, TYPE)
        meta.assert_valid_values_for(:store, STORE)

        assert_ramdisk_and_kernel_image(meta)
      end

      # Validates that incoming query filters fields are valid.
      #
      # @param [Hash] filters The image metadata filters comming from a GET request.
      #
      # @raise[ArgumentError] If some of the query filter fields do not respect the
      #   possible values.
      #
      def validate_query_filters(filters)
        filters.assert_valid_keys(FILTERS.collect { |el| el.to_s })

      end

      private

      # Assert that an image referenced as the corresponding kernel or ramdisk image
      # is present and is a kernel or ramdisk image.
      #
      # @param [Hash] meta The image metadata.
      #
      # @raise[ArgumentError] If the referenced image is not a kernel or ramdisk image.
      #
      def assert_ramdisk_and_kernel_image(meta)
        unless meta[:kernel].nil?
          type = get_image(meta[:kernel])['type']
          if type != 'kernel' && meta[:format] != 'aki'
            raise ArgumentError, "The image with id #{meta[:kernel]} is not a kernel image"
          end
        end
        unless meta[:ramdisk].nil?
          type = get_image(meta[:ramdisk])['type']
          if type != 'ramdisk' && meta[:format] != 'ari'
            raise ArgumentError, "The image with id #{meta[:ramdisk]} is not a ramdisk image"
          end
        end
      end

      # Generate a message with the possible values for a given attribute.
      #
      # @param [Symbol] attr The attribute.
      # @param [String] value The current invalid attribute value.
      #
      def invalid_options_for attr, value
        options = self.class.const_get(attr.to_s.upcase).join(', ')
        "Invalid image #{attr.to_s} '#{value}', available options:\n  #{options}"
      end

    end
  end
end
