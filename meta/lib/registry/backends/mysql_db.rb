require 'mysql2'

module Visor::Registry
  module Backends
    class MySQL < Base

      #TODO: handle other fields, probably stored in 'others' collumn in plain json
      # Connection constants
      #
      # Default MySQL database
      DEFAULT_DB = 'visor'
      # Default MySQL host address
      DEFAULT_HOST = '127.0.0.1'
      # Default MySQL host port
      DEFAULT_PORT = 3306
      # Default MySQL user
      DEFAULT_USER = 'visor'
      # Default MySQL password
      DEFAULT_PASSWORD = 'passwd'
      # Images table schema
      CREATE_TABLE = %[
        CREATE TABLE IF NOT EXISTS `visor`.`images` (
          `_id` VARCHAR(36) NOT NULL ,
          `uri` VARCHAR(255) NULL ,
          `name` VARCHAR(45) NOT NULL ,
          `architecture` VARCHAR(45) NOT NULL ,
          `access` VARCHAR(45) NOT NULL ,
          `type` VARCHAR(45) NULL ,
          `format` VARCHAR(45) NULL ,
          `store` VARCHAR(255) NULL ,
          `kernel` VARCHAR(32) NULL ,
          `ramdisk` VARCHAR(32) NULL ,
          `owner` VARCHAR(45) NULL ,
          `status` VARCHAR(45) NULL ,
          `size` INT NULL ,
          `created_at` DATETIME NULL ,
          `uploaded_at` DATETIME NULL ,
          `updated_at` DATETIME NULL ,
          `accessed_at` DATETIME NULL ,
          `access_count` INT NULL DEFAULT 0 ,
          `checksum` VARCHAR(255) NULL ,
          PRIMARY KEY (`_id`) )
          ENGINE = InnoDB;
      ]

      #CREATE DATABASE visor;
      #CREATE USER 'visor'@'localhost' IDENTIFIED BY 'visor';
      #SET PASSWORD FOR 'visor'@'localhost' = PASSWORD('passwd');
      #GRANT ALL PRIVILEGES ON visor.* TO 'visor'@'localhost';
	
      # Initializes a MySQL Backend instance.
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :db (MYSQL_DB) The wanted database.
      # @option opts [String] :host (MYSQL_IP) The host address.
      # @option opts [Integer] :port (MYSQL_PORT) The port to be used.
      #
      def self.connect(opts = {})
        opts[:host] ||= DEFAULT_HOST
        opts[:port] ||= DEFAULT_PORT
        opts[:db] ||= DEFAULT_DB
        opts[:user] ||= DEFAULT_USER
        opts[:password] ||= DEFAULT_PASSWORD
        self.new opts
      end

      def initialize(opts)
        super opts
      end

      # Establishes and returns a MySQL database connection and
      # creates Images table if it does not exists.
      #
      # @return [Mysql2::Client] It returns a database client object.
      #
      def connection
        Mysql2::Client.new(host: @host, port: @port, database: @db,
                           username: DEFAULT_USER, password: DEFAULT_PASSWORD)
      end

      # Returns the requested image metadata.
      #
      # @param [Integer] id The requested image's i
      #
      # @return [Hash] The requested image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def get_image(id, pass_timestamps = false)
        conn = connection
        meta = conn.query("SELECT #{exclude} FROM images WHERE _id='#{id}'", symbolize_keys: true).first
        raise Visor::NotFound, "No image found with id '#{id}'." if meta.nil?

        set_protected_get(id, conn) unless pass_timestamps
        conn.close
        meta
      end

      # Returns an array with the public images metadata.
      #
      # @param [true, false] brief (false) If true, the returned images will
      #   only contain BRIEF attributes.
      #
      # @option [Hash] filters Image attributes for filtering the returned results.
      #   Besides common attributes filters, the following options can be passed to.
      #
      # @option opts [String] :sort (_id) The image attribute to sort returned results.
      #
      # @return [Array] The public images metadata.
      #
      # @raise [NotFound] If there is no public images.
      #
      def get_public_images(brief = false, filters = {})
        validate_query_filters filters unless filters.empty?

        sort = [(filters.delete(:sort) || '_id'), (filters.delete(:dir) || 'asc')]
        filter = {access: 'public'}.merge(filters)
        fields = brief ? BRIEF.join(', ') : exclude

        pub = connection.query("SELECT #{fields} FROM images WHERE #{to_sql_where(filter)} ORDER BY #{sort[0]} #{sort[1]}",
                               symbolize_keys: true).to_a

        raise Visor::NotFound, "No public images found." if pub.empty? && filters.empty?
        raise Visor::NotFound, "No public images found with given parameters." if pub.empty?
        connection.close
        pub
      end

      # Delete an image record.
      #
      # @param [Integer] id The image's id to remove.
      #
      # @return [Hash] The deleted image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def delete_image(id)
        meta = connection.query("SELECT * FROM images WHERE _id='#{id.to_s}'", symbolize_keys: true).first
        raise Visor::NotFound, "No image found with id '#{id.to_s}'." if meta.nil?

        connection.query "DELETE FROM images WHERE _id='#{id.to_s}'"
        connection.close
        meta
      end

      # Delete all images records.
      #
      def delete_all!
        connection.query "DELETE FROM images"
        connection.close
      end

      # Create a new image record for the given metadata.
      #
      # @param [Hash] meta The metadata.
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :owner (Nil) The owner of the image.
      # @option opts [Integer] :size (Nil) The image file size.
      #
      # @return [Fixnum] The created image _id.
      # @raise [Invalid] If image meta validation fails.
      #
      def post_image(meta, opts = {})
        validate_data_post meta

        meta = {_id: SecureRandom.uuid}.merge!(meta)
        set_protected_post meta, opts

        keys_values = to_sql_insert(meta)
        connection.query "INSERT INTO images #{keys_values[0]} VALUES #{keys_values[1]}"
        connection.close
        self.get_image(meta[:_id], true)
      end

      # Update an image's metadata.
      #
      # @param [Integer] id The image id to update.
      # @param [Hash] update The image metadata to update.
      #
      # @return [Hash] The updated image metadata.
      # @raise [Invalid] If update metadata validation fails.
      # @raise [NotFound] If image not found.
      #
      def put_image(id, update)
        validate_data_put update

        img = connection.query("SELECT * FROM images WHERE _id='#{id.to_s}'", symbolize_keys: true).first
        raise Visor::NotFound, "No image found with id '#{id}'." if img.nil?

        set_protected_put update
        connection.query "UPDATE images SET #{to_sql_update(update)} WHERE _id='#{id.to_s}'"
        connection.close
        self.get_image(id, true)
      end


      private

      # Generates a compatible SQL WHERE string from a hash.
      #
      # @param [Hash] h The input hash.
      #
      # @return [String] A string as "k='v' AND k1='v1'",
      #   only Strings or Times values are surrounded with '<value>'.
      #
      def to_sql_where(h)
        h.map { |k, v| (v.is_a?(String) or v.is_a?(Time)) ? "#{k}='#{v}'" : "#{k}=#{v}" }.join(' AND ')
      end

      # Generates a compatible SQL UPDATE string from a hash.
      #
      # @param [Hash] h The input hash.
      #
      # @return [String] A string as "k='v', k1='v1'",
      #   only Strings or Times values are surrounded with '<value>'.
      #
      def to_sql_update(h)
        h.map { |k, v| (v.is_a?(String) or v.is_a?(Time)) ? "#{k}='#{v}'" : "#{k}=#{v}" }.join(', ')
      end

      # Generates a compatible SQL INSERT string from a hash.
      #
      # @param [Hash] h The input hash.
      #
      # @return [String] A string as "(k, k1) VALUES ('v', 'v1')",
      #   only Strings or Times values are surrounded with '<value>'.
      #
      def to_sql_insert(h)
        surround = h.values.map { |v| (v.is_a?(String) or v.is_a?(Time)) ? "'#{v}'" : v }
        ["(#{h.keys.join(', ')})", "(#{surround.join(', ')})"]
      end

      # Retrieve a hash with all fields that should not be retrieved from database.
      # This sets each key to 0, so Mongo ignores each one of the keys present in it.
      #
      # @return [Hash] The image parameters that should not be retrieved from database.
      #
      def exclude
        (ALL - DETAIL_EXC).join(', ')
      end

      # Atomically set protected fields value from a get operation.
      # Being them the accessed_at and access_count.
      #
      # @param [Fixnum] id The id of the image being retrieved.
      # @param [Mongo::Connection] conn The connection to the database.
      #
      def set_protected_get id, conn
        conn.query "UPDATE images SET accessed_at='#{Time.now}', access_count=access_count+1 WHERE _id='#{id.to_s}'"
      end

      # Set protected fields value from a post operation.
      # Being them the uri, owner, size, status and created_at.
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
      def set_protected_post meta, opts = {}
        owner, size = opts[:owner], opts[:size]

        host = Visor::Registry::Server::HOST
        port = Visor::Registry::Server::PORT
        uri = "http://#{host}:#{port}/images/#{meta[:_id]}"

        meta.merge!(access: 'public') unless meta[:access]
        meta.merge!(owner: owner) if owner
        meta.merge!(size: size) if size
        meta.merge!(created_at: Time.now, uri: uri, status: 'locked')
      end

      # Set protected fields value from a get operation.
      # Being them the accessed_at and access_count.
      #
      # @param [Hash] meta The image metadata update.
      #
      # @return [Hash] The image metadata update with protected fields setted.
      #
      def set_protected_put meta
        meta.merge!(updated_at: Time.now)
      end

    end
  end
end

