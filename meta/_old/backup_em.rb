require 'em-synchrony'
require 'em-synchrony/em-mongo'
require 'json'

require File.expand_path(File.dirname(__FILE__) + '/../constants')
require File.expand_path(File.dirname(__FILE__) + '/../exceptions')

#TODO raise exceptions instead of returning nil
module Metadata
  module API
    class Mongo

      # Establishes and returns a MongoDB database connection.
      #
      # @param [String] db The database with the images collection.
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :coll (nil) The wanted collection.
      # @option opts [String] :host ('127.0.0.1') The host address.
      # @option opts [Integer] :port (27017) The port to be used.
      #
      # @return [EventMachine:Mongo:Database] If no collection is provided it returns a database object.
      # @return [EventMachine::Mongo::Collection] If a collection is provided it returns a collection object.
      #
      def self.configure_db(db='cbolt', opts={})
        coll = opts[:coll] || nil
        host = opts[:host] || '127.0.0.1'
        port = (opts[:port] || 27017).to_i
        # if counters collection is empty then configure it
        res = EM::Mongo::Connection.new(host, port).db(db).collection('counters').find
        configure_counters(db) if res.empty?
        # configure and return database connection
        if coll.nil?
          EM::Mongo::Connection.new(host, port).db(db)
        else
          EM::Mongo::Connection.new(host, port).db(db).collection(coll)
        end
      end

      # Establishes a separated collection to store the sequential _id value
      # for atomically generate a new sequential id overriding the default Mongo OID.
      #
      # @param [String] db The database with the images collection.
      # @option [Hash] opts Any of the available options can be passed.
      #
      # @option opts [String] :host ('127.0.0.1') The host address.
      # @option opts [Integer] :port (27017) The port to be used.
      #
      def self.configure_counters(db='cbolt', opts={})
        host = opts[:host] || '127.0.0.1'
        port = opts[:port] || 27017
        conn = EM::Mongo::Connection.new(host, port).db(db)
        coll = conn.collection('counters')

        if coll.find({_id: 'id'}).empty?
          coll.insert({_id: 'id', count: 1})
          coll.find()
          coll.find_and_modify(query: {_id: 'id'}, update: {:$inc => {count: 1}})
        end
      end


      # Returns an array with the public images metadata.
      #
      # @param [String] db The database with the images collection.
      # @return [Array, Nil] The public images metadata or nil If there is no public images.
      #
      def self.get_public_images(db='cbolt')
        images = configure_db(db, :coll => 'images')
        pub = images.find({access: 'public'}, {order: '_id'})
        return pub unless pub.empty?
        nil
      end

      # Returns the requested image metadata.
      #
      # @param [Integer] id The requested image's id.
      # @param [String] db The database with the images collection.
      # @return [BSON::OrderedHash, Nil] The requested image metadata or nil if image not found.
      #
      def self.get_image(id, db='cbolt')
        images = configure_db(db, :coll => 'images')
        images.find({_id: id}).first
      end

      # Delete an image record.
      #
      # @param [Integer] id The image's id to remove.
      # @param [String] db The database with the images collection.
      # @return [BSON::OrderedHash, Nil] The deleted image metadata or nil if image not found.
      #
      def self.delete_image(id, db='cbolt')
        images = configure_db(db, :coll => 'images')
        res = images.find({_id: id})
        images.remove({_id: id}) unless res.empty?
        res.first
      end

      # Create a new image record for the given metadata.
      #
      # @param [Hash] meta The image's metadata.
      # @param [String] db The database with the images collection.
      # @return [Integer, Nil] The created image id or nil if validation fails.
      #
      def self.post_image(meta, db='cbolt')
        # validate data and connect to db
        #validate_data(meta) #TODO: Image data validation
        db = configure_db(db)
        # atomically generate a new sequential _id overriding the default OID
        counters = db.collection('counters')
        counters.find_and_modify(query: {_id: 'id'}, update: {:$inc => {count: 1}})
        id = counters.find[0]['count']
        # insert the new image
        data = Hash[_id: id.to_i].merge(meta)
        res = db.collection('images').insert(data)
        res
      end

      # Update an image's metadata.
      #
      # @param [Integer] id The image id to update.
      # @param [Hash] update The image metadata to update.
      # @param [String] db The database with the images collection.
      # @return [BSON::OrderedHash, Nil] The updated image metadata or nil if image not found.
      #
      def self.put_image(id, update, db='cbolt')
        # validate data and connect to db
        #validate_data(update) #TODO: Image data validation
        images = configure_db(db, :coll => 'images')
        # find image to update
        res = images.find({_id: id})
        # if image was not found 'res' is an empty
        return nil if res.empty?
        # update image's metadata
        meta = res.first
        meta.merge!(JSON.parse(update.to_json))
        images.update({_id: id}, meta, {upsert: 'true'})
        meta
      end


      def self.set_protected_fields(meta)
        # TODO uri
        # status
        meta.merge!({:status => 'locked'})
        # updated_at
        meta.merge!({:updated_at => Time.now})
      end


      def self.validate_data(meta)
        # assert mandatory fields
        Metadata::MANDATORY.each do |field|
          unless meta.has_key?(field)
            raise Metadata::InvalidError, "The #{field} field is required."
          end
        end

        # assert that no read-only field is setted
        meta.each_key do |key|
          if Metadata::READONLY.include?(key)
            raise Metadata::InvalidError, "the #{key} field is read-only."
          end
        end

        # assert architecture
        arch = meta['architecture']
        unless Metadata::ARCH.include?(arch)
          msg = "Invalid image architecture '#{arch}'\n"
          msg += "Available options: #{Metadata::ARCH.join(', ')}"
          raise Metadata::InvalidError, msg
        end

        # assert access
        access = meta['access']
        unless Metadata::ACCESS.include?(access)
          msg = "Invalid image access '#{access}'\n"
          msg += "Available options: #{Metadata::ACCESS.join(', ')}"
          raise Metadata::InvalidError, msg
        end

        # assert format, if not defined, define it to 'none'
        meta['format'] = 'none' if meta['format'].nil?
        format = meta['format']
        unless Metadata::FORMATS.include?(format)
          msg = "Invalid image format '#{format}'\n"
          msg += "Available options: #{Metadata::FORMATS.join(', ')}"
          raise Metadata::InvalidError, msg
        end

        # assert type, if not defined, define it to 'none'
        meta['type'] = 'none' if meta['type'].nil?
        type = meta['type']
        unless Metadata::TYPES.include?(type)
          msg = "Invalid image format '#{type}'\n"
          msg += "Available options: #{Metadata::TYPES.join(', ')}"
          raise Metadata::InvalidError, msg
        end

        # assert store
        store = meta['store']
        unless Metadata::STORES.include?(store) || store.nil?
          msg = "Invalid image store '#{store}'\n"
          msg += "Available options: #{Metadata::STORES.join(', ')}"
          raise Metadata::InvalidError, msg
        end

        #return the validated metadata
        meta
      end

    end
  end
end

#EventMachine.synchrny do
  data = {
      name: 'abc',
      architecture: 'x8_64',
      access: 'public',
      type: 'amazon',
      disk: 'ami',
      store: 's3'
  }

  up = {
      :name => 'Ubuntu xyz',
      :architecture => 'i386',
      :access => 'public'
  }

  up1 = {
      'name' => 'Ubuntu xyz',
      'architecture' => 'i386',
      'access' => 'public',
      'format' => 'vmdk',
      'type' => 'none',
      'store' => 's3'
  }
#
#  #p = API::Mongo.post_image(data).inspect
#  #p = delete_image(1000).inspect
#  #p = put_image(45, up)
#  #p = API::Mongo.get_image(10)
#  #p = API::Mongo.configure_db
#  #API::Mongo.get_public_images.each { |a| puts a }
#
#  #puts '-', p.inspect, p.class
#  #configure_db(nil, 'abc')
#  #configure_counters('abc')
#
#  EventMachine.stop
#end
#Metadata::API::Mongo.validate_data(up1)
Metadata::API::Mongo.set_protected_fields(up)
puts up
#
#{ "_id" : 1, "name" : "Ubuntu 11.04 Server", "architecture" : "x86_64", "access" : "public", "store" : "swift", "other" : { "release" : 2011 } }
#{ "_id" : 2, "name" : "CentOS 6.0", "architecture" : "x86_64", "access" : "public", "store" : "swift", "disk" : "vmdk", "other" : { "release" : 2010 } }
#{ "_id" : 3, "name" : "Ubuntu 11.10", "architecture" : "i386", "access" : "public", "store" : "s3", "other" : { "release" : 2011 } }
