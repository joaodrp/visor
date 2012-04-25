require 'mongo'
require 'uri'

module Visor
  module Auth
    module Backends

      # The MongoDB Backend for the VISoR Auth.
      #
      class MongoDB < Base

        include Visor::Common::Exception

        # Connection constants
        #
        # Default MongoDB database
        DEFAULT_DB       = 'visor'
        # Default MongoDB host address
        DEFAULT_HOST     = '127.0.0.1'
        # Default MongoDB host port
        DEFAULT_PORT     = 27017
        # Default MongoDB user
        DEFAULT_USER     = nil
        # Default MongoDB password
        DEFAULT_PASSWORD = nil

        # Initializes a MongoDB Backend instance.
        #
        # @option [Hash] opts Any of the available options can be passed.
        #
        # @option opts [String] :uri The connection uri, if provided, no other option needs to be setted.
        # @option opts [String] :db (DEFAULT_DB) The wanted database.
        # @option opts [String] :host (DEFAULT_HOST) The host address.
        # @option opts [Integer] :port (DEFAULT_PORT) The port to be used.
        # @option opts [String] :user (DEFAULT_USER) The user to be used.
        # @option opts [String] :password (DEFAULT_PASSWORD) The password to be used.
        # @option opts [Object] :conn The connection pool to access database.
        #
        def self.connect(opts = {})
          opts[:uri]      ||= ''
          uri             = URI.parse(opts[:uri])
          opts[:db]       = uri.path ? uri.path.gsub('/', '') : DEFAULT_DB
          opts[:host]     = uri.host || DEFAULT_HOST
          opts[:port]     = uri.port || DEFAULT_PORT
          opts[:user]     = uri.user || DEFAULT_USER
          opts[:password] = uri.password || DEFAULT_PASSWORD

          self.new opts
        end

        def initialize(opts)
          super opts
          @conn = connection
        end

        # Establishes and returns a MongoDB database connection.
        #
        # @return [Mongo::Collection] A MongoDB collection object.
        #
        def connection
          db = Mongo::Connection.new(@host, @port, :pool_size => 10, :pool_timeout => 5).db(@db)
          db.authenticate(@user, @password) unless @user.empty? && @password.empty?
          db.collection('users')
        end

        # Returns an array with the registered users.
        #
        # @option [Hash] filters Users attributes for filtering the returned results.
        #   Besides common attributes filters, the following options can be passed to.
        #
        # @return [Array] The users information.
        #
        # @raise [NotFound] If there are no registered users.
        #
        def get_users(filters = {})
          validate_query_filters filters unless filters.empty?
          users = @conn.find(filters).to_a
          raise NotFound, "No users found." if users.empty? && filters.empty?
          raise NotFound, "No users found with given parameters." if users.empty?
          users
        end

        # Returns an user information.
        #
        # @param [String] access_key The user access_key.
        #
        # @return [BSON::OrderedHash] The requested user information.
        #
        # @raise [NotFound] If user was not found.
        #
        def get_user(access_key)
          user = @conn.find_one(access_key: access_key)
          raise NotFound, "No user found with Access Key '#{access_key}'." unless user
          user
        end

        # Delete a registered user.
        #
        # @param [String] access_key The user access_key.
        #
        # @return [BSON::OrderedHash] The deleted image metadata.
        #
        # @raise [NotFound] If user was not found.
        #
        def delete_user(access_key)
          user = @conn.find_one(access_key: access_key)
          raise NotFound, "No user found with Access Key '#{access_key}'." unless user
          @conn.remove(access_key: access_key)
          user
        end

        # Delete all registered users.
        #
        def delete_all!
          @conn.remove
        end

        # Create a new user record for the given information.
        #
        # @param [Hash] user The user information.
        #
        # @return [BSON::OrderedHash] The already added user information.
        #
        # @raise [Invalid] If user information validation fails.
        # @raise [ConflictError] If an access_key was already taken.
        #
        def post_user(user)
          validate_data_post user
          exists = @conn.find_one(access_key: user[:access_key])
          raise ConflictError, "The Access Key '#{user[:access_key]}' was already taken." if exists
          set_protected_post user
          @conn.insert(user)
          self.get_user(user[:access_key])
        end

        # Update an user information.
        #
        # @param [String] access_key The user access_key.
        # @param [Hash] update The user information update.
        #
        # @return [BSON::OrderedHash] The updated user information.
        #
        # @raise [Invalid] If user information validation fails.
        # @raise [ConflictError] If an access_key was already taken.
        # @raise [NotFound] If user was not found.
        #
        def put_user(access_key, update)
          validate_data_put update
          user = @conn.find_one(access_key: access_key)
          raise NotFound, "No user found with Access Key '#{access_key}'." unless user
          if update[:access_key]
            exists = @conn.find_one(access_key: update[:access_key])
            raise ConflictError, "The Access Key '#{update[:access_key]}' was already taken." if exists
          end
          set_protected_put update
          @conn.update({access_key: access_key}, :$set => update)
          self.get_user(update[:access_key] || access_key)
        end

      end
    end
  end
end


