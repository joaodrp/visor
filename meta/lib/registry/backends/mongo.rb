module Cbolt
  module Backends
    class MongoDB < Backend

      # Default database
      MONGO_DB = 'cbolt'
      # Default host address
      MONGO_IP = '127.0.0.1'
      # Default host port
      MONGO_PORT = 27017

      # Initializes a MongoDB Backend instance
      #
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :db (MONGO_DB) The wanted database.
      # @option opts [String] :host (MONGO_IP) The host address.
      # @option opts [Integer] :port (MONGO_PORT) The port to be used.
      #
      def initialize(opts = {})
        db = opts[:db] || MONGO_DB
        host = opts[:host] || MONGO_IP
        port = opts[:port] || MONGO_PORT
        super(db, host, port)
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

      # Returns an array with the public images metadata.
      #
      # @return [Array] The public images metadata
      # @raise [NotFound] If there is no public images.
      #
      def get_public_images(brief = false, filters = {})
        images = connection :images
        # assemble default filter
        base = {:access => 'public'}
        sort = filters.delete :sort || '_id'
        # return brief information
        if brief
          pub = images.find(base, {:fields => BRIEF, :sort => sort}).to_a
          # return with filters
        elsif !filters.empty?
          pub = images.find(base.merge(filters), :sort => sort).to_a
          exclude_details(pub)
          # return detailed information
        else
          pub = images.find(base, :sort => sort).to_a
          exclude_details(pub)
        end

        raise NotFound, "No public images found." if pub.empty?
        pub
      end

      # Returns the requested image metadata.
      #
      # @param [Integer] id The requested image's i
      #
      # @return [BSON::OrderedHash] The requested image metadata.
      # @raise [NotFound] If image not found.
      #
      def get_image(id)
        images = connection :images
        id.is_a?(BSON::ObjectId) ? id : id = id.to_i
        img = images.find(:_id => id).to_a.first
        raise NotFound, "No image found with id '#{id}'." if img.nil?
        set_protected :get, img
        images.update({:_id => id}, img, {:upsert => 'true'})
        exclude_details(img)
        img
      end

      # Delete an image record.
      #
      # @param [Integer] id The image's id to remove.
      # @return [BSON::OrderedHash] The deleted image metadata.
      # @raise [NotFound] If image not found.
      #
      def delete_image(id)
        images = connection :images
        id.is_a?(BSON::ObjectId) ? id : id = id.to_i
        img = images.find(:_id => id).to_a.first
        raise NotFound, "No image found with id '#{id}'." if img.nil?
        images.remove(:_id => id)
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
        validate_data :post, meta
        meta = {:_id => counters(:images)}.merge!(meta)
        set_protected :post, meta, opts
        images = connection :images
        images.insert(meta)
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
        validate_data :put, update
        set_protected :put, update
        images = connection :images
        # find image to update
        id.is_a?(BSON::ObjectId) ? id : id = id.to_i
        img = images.find(:_id => id).to_a.first
        raise NotFound, "No image found with id '#{id}'." if img.nil?
        # update image's metadata
        img.merge!(update.stringify_keys)
        images.update({:_id => id}, img, {:upsert => 'true'})
        img
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

      def exclude_details(obj)
        if obj.is_a?(Array)
          obj.each { |h| DETAIL_EXC.each { |attr| h.delete(attr.to_s) } }
        else
          DETAIL_EXC.each { |attr| obj.delete(attr) }
        end
      end

    end
  end
end

