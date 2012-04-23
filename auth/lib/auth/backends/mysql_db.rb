require 'mysql2'
require 'json'
require 'uri'

module Visor
  module Auth
    module Backends

      # The MySQL Backend for the VISoR Auth.
      #
      class MySQL < Base
        include Visor::Common::Exception

        # Connection constants
        #
        # Default MySQL database
        DEFAULT_DB       = 'visor'
        # Default MySQL host address
        DEFAULT_HOST     = '127.0.0.1'
        # Default MySQL host port
        DEFAULT_PORT     = 3306
        # Default MySQL user
        DEFAULT_USER     = 'visor'
        # Default MySQL password
        DEFAULT_PASSWORD = 'passwd'

        #CREATE DATABASE visor;
        #CREATE USER 'visor'@'localhost' IDENTIFIED BY 'visor';
        #SET PASSWORD FOR 'visor'@'localhost' = PASSWORD('passwd');
        #GRANT ALL PRIVILEGES ON visor.* TO 'visor'@'localhost';

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
          @conn.query %[
        CREATE TABLE IF NOT EXISTS `#{opts[:db]}`.`users` (
          `_id` VARCHAR(45) NOT NULL ,
          `username` VARCHAR(45) NOT NULL ,
          `password` VARCHAR(45) NOT NULL ,
          `email` VARCHAR(45) NOT NULL ,
          `created_at` DATETIME NULL ,
          `updated_at` DATETIME NULL ,
          PRIMARY KEY (`_id`) )
          ENGINE = InnoDB;
        ]
        end

        # Establishes and returns a MySQL database connection and
        # creates Images table if it does not exists.
        #
        # @return [Mysql2::Client] It returns a database client object.
        #
        def connection
          Mysql2::Client.new(host:     @host, port: @port, database: @db,
                             username: @user, password: @password)
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
          filter = filters.empty? ? 1 : to_sql_where(filters)
          users = @conn.query("SELECT * FROM users WHERE #{filter}", symbolize_keys: true).to_a
          raise NotFound, "No users found." if users.empty? && filters.empty?
          raise NotFound, "No users found with given parameters." if users.empty?
          users
        end

        # Returns an user information.
        #
        # @param [String] username The user username.
        #
        # @return [Hash] The requested user information.
        #
        # @raise [NotFound] If user was not found.
        #
        def get_user(username)
          user = @conn.query("SELECT * FROM users WHERE username='#{username}'", symbolize_keys: true).first
          raise NotFound, "No user found with username '#{username}'." unless user
          user
        end

        # Delete a registered user.
        #
        # @param [String] username The user username.
        #
        # @return [hash] The deleted image metadata.
        #
        # @raise [NotFound] If user was not found.
        #
        def delete_user(username)
          user = @conn.query("SELECT * FROM users WHERE username='#{username}'", symbolize_keys: true).first
          raise NotFound, "No user found with username '#{username}'." unless user
          @conn.query "DELETE FROM users WHERE username='#{username}'"
          user
        end

        # Delete all images records.
        #
        def delete_all!
          @conn.query "DELETE FROM users"
        end

        # Create a new user record for the given information.
        #
        # @param [Hash] user The user information.
        #
        # @return [Hash] The already added user information.
        #
        # @raise [Invalid] If user information validation fails.
        # @raise [ConflictError] If an username was already taken.
        #
        def post_user(user)
          validate_data_post user
          exists = @conn.query("SELECT * FROM users WHERE username='#{user[:username]}'", symbolize_keys: true).first
          raise ConflictError, "The username '#{user[:username]}' was already taken." if exists

          set_protected_post user
          keys_values = to_sql_insert(user)
          @conn.query "INSERT INTO users #{keys_values[0]} VALUES #{keys_values[1]}"
          self.get_user(user[:username])
        end

        # Update an user information.
        #
        # @param [String] username The user username.
        # @param [Hash] update The user information update.
        #
        # @return [BSON::OrderedHash] The updated user information.
        #
        # @raise [Invalid] If user information validation fails.
        # @raise [ConflictError] If an username was already taken.
        # @raise [NotFound] If user was not found.
        #
        def put_user(username, update)
          validate_data_put update
          user = @conn.query("SELECT * FROM users WHERE username='#{username}'", symbolize_keys: true).first
          raise NotFound, "No user found with username '#{username}'." unless user

          if update[:username]
            exists = @conn.query("SELECT * FROM users WHERE username='#{update[:username]}'", symbolize_keys: true).first
            raise ConflictError, "The username '#{update[:username]}' was already taken." if exists
          end

          set_protected_put update
          @conn.query "UPDATE users SET #{to_sql_update(update)} WHERE username='#{username}'"
          self.get_user(update[:username] || username)
        end

      end
    end
  end
end

