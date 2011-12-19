require 'mysql2'
require 'json'
require 'uri'

module Visor::Registry
  module Backends

    # The MySQL Backend for the VISoR Registry.
    #
    class MySQL < Base

      include Visor::Common::Exception

      #TODO: handle other fields, probably stored in 'others' collumn in plain json
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

      # Initializes a MySQL Backend instance.
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :uri The connection uri, if provided, no other option needs to be setted.
      # @option opts [String] :db (DEFAULT_DB) The wanted database.
      # @option opts [String] :host (DEFAULT_HOST) The host address.
      # @option opts [Integer] :port (DEFAULT_PORT) The port to be used.
      # @option opts [String] :user (DEFAULT_USER) The user to be used.
      # @option opts [String] :password (DEFAULT_PASSWORD) The password to be used.
      #
      def self.connect(opts = {})
        if opts[:uri]
          uri             = URI.parse(opts[:uri])
          opts[:host]     = uri.host=='' ? DEFAULT_HOST : uri.host
          opts[:port]     = uri.port=='' ? DEFAULT_PORT : uri.port
          opts[:db]       = uri.path=='' ? DEFAULT_DB : uri.path.gsub('/', '')
          opts[:user]     = uri.user=='' ? DEFAULT_USER : uri.user
          opts[:password] = uri.password=='' ? DEFAULT_PASSWORD : uri.password
        else
          opts[:host]     ||= DEFAULT_HOST
          opts[:port]     ||= DEFAULT_PORT
          opts[:db]       ||= DEFAULT_DB
          opts[:user]     ||= DEFAULT_USER
          opts[:password] ||= DEFAULT_PASSWORD
        end
        self.new opts
      end

      def initialize(opts)
        super opts
        conn = connection
        conn.query %[
        CREATE TABLE IF NOT EXISTS `#{opts[:db]}`.`images` (
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
          `others` VARCHAR(255) NULL,
          PRIMARY KEY (`_id`) )
          ENGINE = InnoDB;
        ]
        conn.close
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

      # Returns the requested image metadata.
      #
      # @param [String] id The requested image's _id.
      #
      # @return [Hash] The requested image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def get_image(id, pass_timestamps = false)
        conn = connection
        meta = conn.query("SELECT * FROM images WHERE _id='#{id}'", symbolize_keys: true).first
        raise NotFound, "No image found with id '#{id}'." if meta.nil?

        set_protected_get(id, conn) unless pass_timestamps
        conn.close

        exclude(meta)
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

        conn   = connection
        sort   = [(filters.delete(:sort) || '_id'), (filters.delete(:dir) || 'asc')]
        filter = {access: 'public'}.merge(filters)
        fields = brief ? BRIEF.join(', ') : '*'

        pub = conn.query("SELECT #{fields} FROM images WHERE #{to_sql_where(filter)}
                                ORDER BY #{sort[0]} #{sort[1]}", symbolize_keys: true).to_a

        raise NotFound, "No public images found." if pub.empty? && filters.empty?
        raise NotFound, "No public images found with given parameters." if pub.empty?
        conn.close
        pub.each { |meta| exclude(meta) } if fields == '*'
        pub
      end

      # Delete an image record.
      #
      # @param [String] id The image's _id to remove.
      #
      # @return [Hash] The deleted image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def delete_image(id)
        conn = connection
        meta = conn.query("SELECT * FROM images WHERE _id='#{id}'", symbolize_keys: true).first
        raise NotFound, "No image found with id '#{id}'." if meta.nil?

        conn.query "DELETE FROM images WHERE _id='#{id}'"
        conn.close
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
      # @return [Hash] The already inserted image metadata.
      # @raise [Invalid] If image meta validation fails.
      #
      def post_image(meta, opts = {})
        validate_data_post meta
        conn = connection

        set_protected_post meta, opts
        serialize_others(meta)

        keys_values = to_sql_insert(meta)
        conn.query "INSERT INTO images #{keys_values[0]} VALUES #{keys_values[1]}"
        conn.close
        self.get_image(meta[:_id], true)
      end

      # Update an image's metadata.
      #
      # @param [String] id The image _id to update.
      # @param [Hash] update The image metadata to update.
      #
      # @return [Hash] The updated image metadata.
      # @raise [Invalid] If update metadata validation fails.
      # @raise [NotFound] If image not found.
      #
      def put_image(id, update)
        validate_data_put update
        conn = connection
        img  = conn.query("SELECT * FROM images WHERE _id='#{id}'", symbolize_keys: true).first
        raise NotFound, "No image found with id '#{id}'." if img.nil?

        set_protected_put update
        serialize_others(update)

        conn.query "UPDATE images SET #{to_sql_update(update)} WHERE _id='#{id}'"
        conn.close
        self.get_image(id, true)
      end


      private

      # Excludes details that should not be disclosed on get detailed image meta.
      # Also deserializes others attributes from the others collumn.
      #
      # @return [Hash] The image parameters that should not be retrieved from database.
      #
      def exclude(meta)
        deserialize_others(meta)
        DETAIL_EXC.each { |key| meta.delete(key) }
      end

      # Atomically set protected fields value from a get operation.
      # Being them the accessed_at and access_count.
      #
      # @param [String] id The _id of the image being retrieved.
      # @param [Mysql2::Client] conn The connection to the database.
      #
      def set_protected_get(id, conn)
        conn.query "UPDATE images SET accessed_at='#{Time.now}', access_count=access_count+1 WHERE _id='#{id}'"
      end

      def serialize_others(meta)
        other_keys = meta.keys - ALL
        others     = {}
        other_keys.each { |key| others[key] = meta.delete(key) }
        meta.merge!(others: others.to_json)
      end

      def deserialize_others(meta)
        others = meta.delete :others
        meta.merge! JSON.parse(others, symbolize_names: true)
      end
    end
  end
end

