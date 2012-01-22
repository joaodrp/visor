module Visor::Meta
  module Backends

    # This is the Base super class for all Backends. Each new backend inherits from Base,
    # which contains the model and all validations for the images metadata.
    #
    # Implementing a new backend is as simple as create a new backend class which inherits
    # from Base and them implement the specific methods for querying the underlying database.
    #
    class Base
      # TODO validate owner user

      # Keys validation
      #
      # Mandatory attributes
      MANDATORY    = [:name, :architecture]
      # Read-only attributes
      READONLY     = [:_id, :uri, :created_at, :updated_at, :accessed_at, :access_count]
      # Optional attributes
      OPTIONAL     = [:owner, :status, :size, :checksum, :access, :type, :format,
                      :uploaded_at, :store, :location, :kernel, :ramdisk]
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
      # Possible storage
      STORE        = %w[s3 swift cumulus hdfs file]

      # Presentation options
      #
      # Brief attributes used to return only brief information about images.
      BRIEF        = [:_id, :uri, :name, :architecture, :type, :format, :store, :size, :created_at]
      # Attributes to exclude from get public images requests, allowing to show other custom attributes.
      DETAIL_EXC   = [:owner, :uploaded_at, :accessed_at, :access_count]
      # Valid parameters to filter results from requests query, add sort parameter and sort direction.
      FILTERS      = ALL + [:sort, :dir]

      attr_reader :db, :host, :port, :user, :password, :conn

      # Initializes a Backend instance.
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :host The host address.
      # @option opts [Integer] :port The port to be used.
      # @option opts [String] :db The wanted database.
      # @option opts [String] :user The username to be authenticate db access.
      # @option opts [String] :password The password to be authenticate db access.
      # @option opts [Object] :conn The connection pool to access database.
      #
      def initialize(opts)
        @host     = opts[:host]
        @port     = opts[:port]
        @db       = opts[:db]
        @user     = opts[:user]
        @password = opts[:password]
        @conn     = opts[:conn]
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

        assert_ramdisk_and_kernel(meta)
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

        assert_ramdisk_and_kernel(meta)
      end

      # Validates that incoming query filters fields are valid.
      #
      # @param [Hash] filters The image metadata filters comming from a GET request.
      #
      # @raise[ArgumentError] If some of the query filter fields do not respect the
      #   possible values.
      #
      def validate_query_filters(filters)
        filters.symbolize_keys!
        filters.assert_valid_keys(FILTERS)

      end

      # Set protected fields value from a post operation.
      # Being them the _id, uri, owner, size, access, status and created_at.
      #
      # @param [Hash] meta The image metadata.
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :owner (Nil) The image owner.
      # @option opts [String] :size (Nil) The image file size.
      #
      # @return [Hash] The image metadata filled with protected fields values.
      #
      def set_protected_post(meta, opts = {})
        owner, size = opts[:owner], opts[:size]
        meta.merge!(_id: SecureRandom.uuid)
        meta.merge!(access: 'public') unless meta[:access]
        meta.merge!(owner: owner) if owner
        meta.merge!(size: size) if size
        meta.merge!(created_at: Time.now, uri: build_uri(meta[:_id]), status: 'locked')
      end

      # Set protected fields value from a get operation.
      # Being them the accessed_at and access_count.
      #
      # @param [Hash] meta The image metadata update.
      #
      # @return [Hash] The image metadata update with protected fields setted.
      #
      def set_protected_put(meta)
        meta.merge!(updated_at: Time.now)
      end

      # Build an URI for the given image _id based on VISoR Regisry Server configuration.
      #
      # @param [String] id The _id of the image.
      #
      # @return [String] The generated URI.
      #
      def build_uri(id)
        conf = Visor::Common::Config.load_config :visor_meta
        host = conf[:bind_host] || Visor::Meta::Server::DEFAULT_HOST
        port = conf[:bind_port] || Visor::Meta::Server::DEFAULT_PORT
        "http://#{host}:#{port}/images/#{id}"
      end

      # Serializes with JSON and encapsulate additional (not on the table schema) image attributes
      # on the others schema field.
      #
      # This is used for SQL Backends, as they are not schema free.
      #
      # @example Instantiate a client with default values:
      #   # So this:
      #   {name: 'example', access: 'public', extra_key: 'value', another: 'value'}
      #   # becomes this:
      #   {name: "example", access: "public", others: "{\"extra_key\":\"value\",\"another\":\"value\"}"}"}
      #
      # @param [Hash] meta The image metadata.
      #
      def serialize_others(meta)
        other_keys = meta.keys - ALL
        unless other_keys.empty?
          others = {}
          other_keys.each { |key| others[key] = meta.delete(key) }
          meta.merge!(others: others.to_json)
        end
      end

      # Deserializes with JSON and decapsulate additional (not on the table schema) image attributes
      # from the others schema field.
      #
      # This is used for SQL Backends, as they are not schema free.
      #
      # @example Instantiate a client with default values:
      #   # So this:
      #   {name: "example", access: "public", others: "{\"extra_key\":\"value\",\"another\":\"value\"}"}"}
      #   # becomes this:
      #   {name: 'example', access: 'public', extra_key: 'value', another: 'value'}
      #
      # @param [Hash] meta The image metadata.
      #
      def deserialize_others(meta)
        if meta[:others]
          others = meta.delete :others
          meta.merge! JSON.parse(others, symbolize_names: true)
        end
      end

      # Verifies if a given object is a String, a Time or a Hash.
      #
      # @param [Object] v The input value.
      #
      # @return [true, false] If the provided value is or not a String, a Time or a Hash.
      #
      def string_time_or_hash?(v)
        v.is_a?(String) or v.is_a?(Time) or v.is_a?(Hash)
      end

      # Generates a compatible SQL WHERE string from a hash.
      #
      # @param [Hash] h The input hash.
      #
      # @return [String] A string as "k='v' AND k1='v1'",
      #   only Strings Times or Hashes values are surrounded with '<value>'.
      #
      def to_sql_where(h)
        h.map { |k, v| string_time_or_hash?(v) ? "#{k}='#{v}'" : "#{k}=#{v}" }.join(' AND ')
      end

      # Generates a compatible SQL UPDATE string from a hash.
      #
      # @param [Hash] h The input hash.
      #
      # @return [String] A string as "k='v', k1='v1'",
      #   only Strings Times or Hashes values are surrounded with '<value>'.
      #
      def to_sql_update(h)
        h.map { |k, v| string_time_or_hash?(v) ? "#{k}='#{v}'" : "#{k}=#{v}" }.join(', ')
      end

      # Generates a compatible SQL INSERT string from a hash.
      #
      # @param [Hash] h The input hash.
      #
      # @return [String] A string as "(k, k1) VALUES ('v', 'v1')",
      #   only Strings Times or Hashes values are surrounded with '<value>'.
      #
      def to_sql_insert(h)
        surround = h.values.map { |v| string_time_or_hash?(v) ? "'#{v}'" : v }
        %W{(#{h.keys.join(', ')}) (#{surround.join(', ')})}
      end

      private

      # Assert that an image referenced as the corresponding kernel or ramdisk image
      # is present and is a kernel or ramdisk image.
      #
      # A valid kernel image is an image that has its type setted to 'kernel'
      # and/or its format setted to 'aki' (Amazon Kernel Image).
      #
      # A valid ramdisk image is an image that has its type setted to 'ramdisk'
      # and/or its format setted to 'ari' (Amazon Ramdisk Image).
      #
      # As all backends implement the same external API, we can call here the #get_image
      # without self and it will pickup the self.get_image method of the backend in use.
      #
      # @param [Hash] meta The image metadata.
      #
      # @raise[NotFound] If the referenced image is not found.
      # @raise[ArgumentError] If the referenced image is not a kernel or ramdisk image.
      #
      def assert_ramdisk_and_kernel(meta)
        if meta[:kernel]
          id   = meta[:kernel]
          type = get_image(id).symbolize_keys[:type]
          if type != 'kernel' && meta[:format] != 'aki'
            raise ArgumentError, "The image with id #{id} is not a kernel image."
          end
        end
        if meta[:ramdisk]
          id   = meta[:ramdisk]
          type = get_image(id).symbolize_keys[:type]
          if type != 'ramdisk' && meta[:format] != 'ari'
            raise ArgumentError, "The image with id #{id} is not a ramdisk image."
          end
        end
      end

      # Generate a message with the possible values for a given attribute.
      #
      # @param [Symbol] attr The attribute.
      # @param [String] value The current invalid attribute value.
      #
      #def invalid_options_for attr, value
      #  options = self.class.const_get(attr.to_s.upcase).join(', ')
      #  "Invalid image #{attr.to_s} '#{value}', available options:\n  #{options}"
      #end

    end
  end
end
