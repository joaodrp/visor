module Cbolt
  module Backends
    class MongoDB < Backend

      #TODO: replace _id with SecureRandom.uuid

      # Connection constants
      #
      # Default MongoDB database
      MONGO_DB = 'cbolt'
      # Default MongoDB host address
      MONGO_IP = '127.0.0.1'
      # Default MongoDB host port
      MONGO_PORT = 27017

      # Initializes a MongoDB Backend instance.
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :db (MONGO_DB) The wanted database.
      # @option opts [String] :host (MONGO_IP) The host address.
      # @option opts [Integer] :port (MONGO_PORT) The port to be used.
      #
      def self.connect(opts = {})
        db = opts[:db] || MONGO_DB
        host = opts[:host] || MONGO_IP
        port = opts[:port] || MONGO_PORT
        self.new(db, host, port)
      end

      def initialize(db, host, port)
        super db, host, port
      end

      # Establishes and returns a MongoDB database connection.
      #
      # @param [String] coll (Nil) The wanted collection.
      #
      # @return [Mongo:DB, Mongo::Collection] It returns a database object or a collection object.
      #
      def connection(coll = nil)
        if coll
          Mongo::Connection.new(@host, @port).db(@db).collection(coll.to_s)
        else
          Mongo::Connection.new(@host, @port).db(@db)
        end
      end

      # Returns the requested image metadata.
      #
      # @param [Integer] id The requested image's i
      #
      # @return [BSON::OrderedHash] The requested image metadata.
      #
      # @raise [NotFound] If image not found.
      #
      def get_image(id)
        conn = connection :images
        id = parse_id id

        meta = conn.find_one({_id: id}, fields: exclude)
        raise NotFound, "No image found with id '#{id}'." if meta.nil?

        set_protected_get id, conn
        meta
      end

      # Returns an array with the public images metadata.
      #
      # @param [TrueClass, FalseClass] brief (false) If true, the returned images will
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
        images = connection :images
        validate_query_filters filters unless filters.empty?

        sort = [(filters.delete('sort') || '_id'), (filters.delete('dir') || 'asc')]
        filter = {access: 'public'}.merge(filters)

        if brief
          pub = images.find(filter, fields: BRIEF, sort: sort).to_a
        else
          pub = images.find(filter, fields: exclude, sort: sort).to_a
        end

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
        conn = connection :images
        id = parse_id id

        img = conn.find_one({_id: id})
        raise NotFound, "No image found with id '#{id}'." if img.nil?

        conn.remove({_id: id})
        img
      end

      # Delete all images records.
      #
      def delete_all!
        conn = connection
        conn.collection('images').remove
        conn.collection('counters').remove
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
        conn = connection :images

        meta = {_id: counters(:images)}.merge!(meta)
        set_protected_post meta, opts
        conn.insert(meta)
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
        conn = connection :images

        id = parse_id id
        img = conn.find_one({_id: id})
        raise NotFound, "No image found with id '#{id}'." if img.nil?

        set_protected_put update
        conn.update({_id: id}, :$set => update)
        img.merge(update.stringify_keys)
      end


      private

      # Increment the counters collection, which will handle the atomic increment of _id
      # instead of using the default Mongo OID. This _id will be assigned to images at insert time.
      #
      # @param [String] name The target collection.
      #
      # @return [Integer] The next sequential _id.
      #
      def counters(name)
        counts = connection :counters
        counts.find_and_modify(:query => {:_id => name.to_s},
                               :update => {:$inc => {:next => 1}},
                               :new => true, :upsert => true)['next']
      end

      # Parse the given id, being it a string, a fixnum or a BSON::ObjectId.
      #
      # @param [Fixnum, String, BSON::ObjectId] id The id to be parsed.
      #
      # @return [Fixnum, BSON::ObjectId] The parsed id.
      #
      def parse_id id
        id.is_a?(BSON::ObjectId) ? id : id.to_i
      end

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
      def set_protected_get id, conn
        conn.update({_id: id}, :$set => {accessed_at: Time.now}, :$inc => {access_count: 1})
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
        owner, size = opts[:owner], opts[:size] # TODO validate owner user
        uri = "http://#{@host}:#{@port}/images/#{meta[:_id]}"

        meta.merge!(created_at: Time.now, uri: uri, status: 'locked')
        meta.merge!(owner: owner) unless owner.nil?
        meta.merge!(size: size) unless size.nil?
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

