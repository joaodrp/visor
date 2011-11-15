require 'em-synchrony'
require 'em-synchrony/em-mongo'
require 'json'

module API
  class Mongo
    # Establishes and returns the MongoDB database connection
    # If no collection is provided (nil) it returns a database object
    #
    # @param coll [String] the wanted collection or nil for no collection
    # @param host [String] the host address
    # @param port [Integer] the port
    # @option db [String] the database with the images collection
    #
    def self.configure_db(coll, db='cbolt', host='127.0.0.1', port=27017)
      if coll.nil?
        EM::Mongo::Connection.new(host, port).db(db)
      else
        EM::Mongo::Connection.new(host, port).db(db).collection(coll)
      end
    end

    # Establishes a separated collection to store the sequential _id value
    # for atomically generate a new sequential _id overriding the default OID
    #
    # @param host [String] the host address
    # @param port [Integer] the port
    # @option db [String] the database with the images collection
    #
    def self.configure_counters(db='cbolt', host='127.0.0.1', port=27017)
      conn = EM::Mongo::Connection.new(host, port).db(db)
      coll = conn.collection('counters')

      if coll.find({_id:'id'}).empty?
        coll.insert({_id:'id', count: 1})
        coll.find()
        coll.find_and_modify(query: {_id: 'id'}, update: {:$inc => {count: 1}})
      end
    end

    def self.validate_data(meta)

    end

    # Returns an array with the public images metadata
    # If no public image is found it returns an empty array.
    #
    # @option db [String] the database with the images collection
    # @return [Array] the public images metadata
    #
    def self.get_public_images(db='cbolt')
      images = configure_db('images', db)
      images.find({access: 'public'}, {order: '_id'})
    end

    # Returns an array with the requested image's metadata
    # If no image is found it returns an empty array.
    #
    # @param id [Integer] the requested image's id
    # @option db [String] the database with the images collection
    # @return [Array] the requested image's metadata
    #
    def self.get_image(id, db='cbolt')
      images = configure_db('images', db)
      images.find({_id: id})
    end

    # Delete an image record
    #
    # @param id [Integer] the image's id to remove
    # @option db [String] the database with the images collection
    # @return [Array] the deleted image's metadata or empty if image not found
    #
    def self.delete_image(id, db='cbolt')
      images = configure_db('images', db)
      res = images.find({_id: id})
      images.remove({_id: id}) unless res.empty?
      res
    end

    # Create a new image record for the given metadata
    #
    # @param meta [Hash] the image's metadata
    # @option db [String] the database with the images collection
    # @return [Integer] the created image id or nil if validation fails
    #
    def self.post_image(meta, db='cbolt')
      # validate data and connect to db
      validate_data(meta) #TODO: Image data validation
      db = configure_db(nil, db)
      # atomically generate a new sequential _id overriding the default OID
      counters = db.collection('counters')
      counters.find_and_modify(query: {_id: 'id'}, update: {:$inc => {count: 1}})
      id = counters.find[0]['count']
      # insert the new image
      data = Hash[_id: id.to_i].merge(meta)
      db.collection('images').insert(data)
    end

    # Update an image's metadata
    #
    # @param id [Integer] the image's id to update
    # @param update [Hash] the the image's metadata to update
    # @option db [String] the database with the images collection
    # @return [Array] the updated image's metadata or empty if image not found
    #
    def self.put_image(id, update, db='cbolt')
      # validate data and connect to db
      validate_data(update) #TODO: Image data validation
      images = configure_db('images', db)
      # find image to update
      res = images.find({_id: id})
      # if image was not found 'res' is an empty array so return it
      return res if res.empty?
      # update image's metadata
      meta = res.first
      meta.merge!(JSON.parse(update.to_json))
      images.update({_id: id}, meta, {upsert: 'true'})
      meta
    end
  end
end

EventMachine.synchrony do
  data = {
      name: 'Ubuntu abc',
      architecture: 'x86_64',
      access: 'public',
      type: 'amazon',
      disk: 'ami',
      store: 's3'
  }

  up = {
      name: 'Ubuntu xyz',
      architecture: 'i386',
      a: 'y'
  }

  up1 = {
      'name' => 'Ubuntu xyz',
      'architecture' => 'i386',
      'b' => 'y'
  }

  #p = post_image(data).inspect
  #p = delete_image(1000).inspect
  #p = put_image(45, up)
  API::Mongo.get_public_images.each { |a| puts a }

  #puts '-', p.inspect
  #configure_db(nil, 'abc')
  #configure_counters('abc')

  EventMachine.stop
end

#
#{ "_id" : 1, "name" : "Ubuntu 11.04 Server", "architecture" : "x86_64", "access" : "public", "store" : "swift", "other" : { "release" : 2011 } }
#{ "_id" : 2, "name" : "CentOS 6.0", "architecture" : "x86_64", "access" : "public", "store" : "swift", "disk" : "vmdk", "other" : { "release" : 2010 } }
#{ "_id" : 3, "name" : "Ubuntu 11.10", "architecture" : "i386", "access" : "public", "store" : "s3", "other" : { "release" : 2011 } }
