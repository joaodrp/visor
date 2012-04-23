module Visor
  module Auth
    module Backends

      # This is the Base super class for all Backends. Each new backend inherits from Base,
      # which contains the model and all validations for the users metadata.
      #
      # Implementing a new backend is as simple as create a new backend class which inherits
      # from Base and them implement the specific methods for querying the underlying database.
      #
      class Base

        # Keys validation
        #
        # Mandatory attributes
        MANDATORY = [:username, :password, :email]
        # Read-only attributes
        READONLY  = [:_id, :created_at, :updated_at]
        # All attributes
        ALL       = MANDATORY + READONLY

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

        # Validates the user information for a post operation, based on possible keys and values.
        #
        # @param [Hash] info The user information.
        #
        # @raise[ArgumentError] If some of the information fields do not respect the
        #   possible values, contains any read-only or misses any mandatory field.
        #
        def validate_data_post(info)
          info.assert_exclusion_keys(READONLY)
          info.assert_inclusion_keys(MANDATORY)
          validate_email(info[:email])
        end

        # Validates the user information for a put operation, based on possible keys and values.
        #
        # @param [Hash] info The user information.
        #
        # @raise[ArgumentError] If some of the metadata fields do not respect the
        #   possible values, contains any read-only or misses any mandatory field.
        #
        def validate_data_put(info)
          info.assert_exclusion_keys(READONLY)
          validate_email(info[:email]) if info[:email]
        end

        # Set protected fields value from a post operation.
        # Being them the _id and created_at.
        #
        # @param [Hash] info The user information.
        #
        # @option [Hash] opts Any of the available options can be passed.
        #
        # @return [Hash] The updated user information.
        #
        def set_protected_post(info)
          info.merge!(_id: SecureRandom.uuid, created_at: Time.now)
        end

        # Set protected field value from a get operation.
        # Being it the updated_at.
        #
        # @param [Hash] info The user information update.
        #
        # @return [Hash] The updated user information.
        #
        def set_protected_put(info)
          info.merge!(updated_at: Time.now)
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

        # Validates that incoming query filters fields are valid.
        #
        # @param [Hash] filters The image metadata filters coming from a GET request.
        #
        # @raise[ArgumentError] If some of the query filter fields do not respect the
        #   possible values.
        #
        def validate_query_filters(filters)
          filters.symbolize_keys!
          filters.assert_valid_keys(ALL)
        end

        private

        # Verifies if a given object is a String, a Time or a Hash.
        #
        # @param [Object] v The input value.
        #
        # @return [true, false] If the provided value is or not a String, a Time or a Hash.
        #
        def string_time_or_hash?(v)
          v.is_a?(String) or v.is_a?(Time) or v.is_a?(Hash)
        end

        # Verifies if a given email string is a valid email.
        #
        # @param [String] s The input value.
        #
        # @raise [ArgumentError] If the email address is invalid.
        #
        def validate_email(s)
          valid = s.match(/([^@\s*]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})/i)
          raise ArgumentError, "The email address seems to be invalid." unless valid
        end

      end
    end
  end
end
