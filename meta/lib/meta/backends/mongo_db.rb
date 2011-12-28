require 'mongo'
require 'uri'

module Visor::Meta
  module Backends

    # The MongoDB Backend for the VISoR Meta.
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
        @conn = connection
      end

      # Establishes and returns a MongoDB database connection.
      #
      # @return [Mongo::Collection] A MongoDB collection object.
      #
      def connection
        db = Mongo::Connection.new(@host, @port, :pool_size => 10, :pool_timeout => 5).db(@db)
        db.authenticate(@user, @password) if @user && @password
        db.collection('images')
      end

      # Returns the requested image metadata.
      #
      # @param [Integer] id The requested image's _id.
      # @param [true, false] pass_timestamps If we want to pass timestamps setting step.
      #
      # @return [BSON::OrderedHash] The requested image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def get_image(id, pass_timestamps = false)
        meta = @conn.find_one({_id: id}, fields: exclude)
        raise NotFound, "No image found with id '#{id}'." if meta.nil?
        set_protected_get id unless pass_timestamps
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

        sort   = [(filters.delete(:sort) || '_id'), (filters.delete(:dir) || 'asc')]
        filter = {access: 'public'}.merge(filters)
        fields = brief ? BRIEF : exclude

        pub = @conn.find(filter, fields: fields, sort: sort).to_a

        raise NotFound, "No public images found." if pub.empty? && filters.empty?
        raise NotFound, "No public images found with given parameters." if pub.empty?

        pub
      end

      # Delete an image record.
      #
      # @param [Integer] id The image's _id to remove.
      #
      # @return [BSON::OrderedHash] The deleted image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def delete_image(id)
        img = @conn.find_one({_id: id})
        raise NotFound, "No image found with id '#{id}'." unless img

        @conn.remove({_id: id})
        img
      end

      # Delete all images records.
      #
      def delete_all!
        @conn.remove
      end

      # Create a new image record for the given metadata.
      #
      # @param [Hash] meta The image metadata.
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :owner (Nil) The owner of the image.
      # @option opts [Integer] :size (Nil) The image file size.
      #
      # @return [BSON::OrderedHash] The already added image metadata.
      # @raise [Invalid] If image meta validation fails.
      #
      def post_image(meta, opts = {})
        validate_data_post meta
        set_protected_post meta, opts
        id = @conn.insert(meta)
        self.get_image(id, true)
      end

      # Update an image's metadata.
      #
      # @param [Integer] id The image _id to update.
      # @param [Hash] update The image metadata to update.
      #
      # @return [BSON::OrderedHash] The updated image metadata.
      # @raise [Invalid] If update metadata validation fails.
      # @raise [NotFound] If image not found.
      #
      def put_image(id, update)
        validate_data_put update

        img = @conn.find_one({_id: id})
        raise NotFound, "No image found with id '#{id}'." unless img

        set_protected_put update
        @conn.update({_id: id}, :$set => update)
        self.get_image(id, true)
      end


      private

      # Retrieve a hash with all fields that should not be retrieved from database.
      # This sets each key to 0, so Mongo ignores each one of the keys present in it.
      #
      # @return [Hash] The image parameters that should not be retrieved from database.
      #
      def exclude
        DETAIL_EXC.inject({}) { |h, v| h[v] = 0; h }
      end

      # Atomically set protected fields value from a get operation.
      # Being them the accessed_at and access_count.
      #
      # @param [String] id The _id of the image being retrieved.
      #
      def set_protected_get(id)
        @conn.update({_id: id}, :$set => {accessed_at: Time.now}, :$inc => {access_count: 1})
      end

    end
  end
end


