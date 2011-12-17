require 'mongo'

module Visor::Registry
  module Backends
    class MongoDB < Base

      include Visor::Common::Exception

      # Connection constants
      #
      # Default MongoDB database
      DEFAULT_DB = 'visor'
      # Default MongoDB host address
      DEFAULT_HOST = '127.0.0.1'
      # Default MongoDB host port
      DEFAULT_PORT = 27017
      # Default MongoDB user
      DEFAULT_USER = nil
      # Default MongoDB password
      DEFAULT_PASSWORD = nil
      # Assembled MongoDB connection URI
      CONNECTION_URI = "mongodb://#{DEFAULT_USER}:#{DEFAULT_PASSWORD}@#{DEFAULT_HOST}:#{DEFAULT_PORT}/#{DEFAULT_DB}"

      # Initializes a MongoDB Backend instance.
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :db (MONGO_DB) The wanted database.
      # @option opts [String] :host (MONGO_IP) The host address.
      # @option opts [Integer] :port (MONGO_PORT) The port to be used.
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
        @conn = connection
        #uri = URI.parse(ENV['MONGOHQ_URL'])
        #conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
        #@db = conn.db(uri.path.gsub(/^\//, ''))
        #@collection = @db.collection("images")
      end

      # Establishes and returns a MongoDB database connection.
      #
      # @return [Mongo:DB, Mongo::Collection] It returns a database object or a collection object.
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

        sort = [(filters.delete(:sort) || '_id'), (filters.delete(:dir) || 'asc')]
        filter = {access: 'public'}.merge(filters)
        fields = brief ? BRIEF : exclude

        pub = @conn.find(filter, fields: fields, sort: sort).to_a

        raise NotFound, "No public images found." if pub.empty? && filters.empty?
        raise NotFound, "No public images found with given parameters." if pub.empty?

        pub
      end

      # Delete an image record.
      #
      # @param [Integer] id The image's id to remove.
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
      # @return [Fixnum] The created image _id.
      # @raise [Invalid] If image meta validation fails.
      #
      def post_image(meta, opts = {})
        validate_data_post meta

        meta = {_id: SecureRandom.uuid}.merge!(meta)
        set_protected_post meta, opts
        id = @conn.insert(meta)
        self.get_image(id, true)
      end

      # Update an image's metadata.
      #
      # @param [Integer] id The image id to update.
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
      # @param [Fixnum] id The id of the image being retrieved.
      # @param [Mongo::Connection] conn The connection to the database.
      #
      def set_protected_get id
        @conn.update({_id: id}, :$set => {accessed_at: Time.now}, :$inc => {access_count: 1})
      end

      # Set protected fields value from a post operation.
      # Being them the uri, owner, size, access, status and created_at.
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
        owner, size = opts[:owner], opts[:size] # TODO validate owner user

        host = Visor::Registry::Server::HOST
        port = Visor::Registry::Server::PORT
        uri = "http://#{host}:#{port}/images/#{meta[:_id]}"

        meta.merge!(access: 'public') unless meta[:access]
        meta.merge!(owner: owner) if owner
        meta.merge!(size: size) if size
        meta.merge!(created_at: Time.now, uri: uri, status: 'locked')

        #meta.set_blank_keys_value_to(Base::BRIEF, [], nil)
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


