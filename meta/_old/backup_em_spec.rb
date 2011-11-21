require 'minitest/autorun'
require 'mongo'
require 'colorific'
require File.dirname(__FILE__) + '/../../api/mongo'


describe Metadata::API::Mongo do

  before do
    # configure a mongo database to run these tests
    db = Mongo::Connection.new.db('mongo-test')
    @coll = db.collection('images')
    # insert a sample image
    @sample = {
        name: 'testsample',
        architecture: 'i386',
        access: 'public',
        type: 'none',
        format: 'disk',
        store: 'none'
    }
    @coll.insert(@sample)
  end

  after do
    # drop the collection and all test operations done on it
    @coll.drop
  end


  describe 'configure database' do
    it "should create a database connection and return the db object" do
      EventMachine.synchrony do
        db = Metadata::API::Mongo.configure_db('mongo-test')
        db.must_be_instance_of EM::Mongo::Database
        EventMachine.stop
      end
    end

    it "should create a database connection to a specific collection" do
      EventMachine.synchrony do
        coll = Metadata::API::Mongo.configure_db('mongo-test', :coll => 'images')
        coll.must_be_instance_of EM::Mongo::Collection
        EventMachine.stop
      end
    end
  end


  describe 'configure counters' do
    it "should configure the counters collection" do
      EventMachine.synchrony do
        Metadata::API::Mongo.configure_counters('mongo-test')
        coll = Metadata::API::Mongo.configure_db('mongo-test', :coll => 'counters')
        id = coll.find[0]['count']
        id.must_be_instance_of Fixnum
        EventMachine.stop
      end
    end
  end


  describe 'validate data' do
    it "should raise an exception if some mandatory field is not provided" do
      misses = []
      misses << {:architecture => 'i386', :access => 'public'}
      misses << {name: 'name', access: 'public'}
      misses << {name: 'name', architecture: 'i386'}
      misses.each do |missing|
        e = Proc.new { Metadata::API::Mongo.validate_data(JSON.parse(missing.to_json)) }
        e.must_raise Metadata::InvalidError
      end
    end

    it "should raise an exception if the user tries to set an read-only field" do
      Metadata::READONLY.each do |field|
        meta = @sample.merge({"#{field}" => 'some_value'})
        e = Proc.new { Metadata::API::Mongo.validate_data(JSON.parse(meta.to_json)) }
        e.must_raise Metadata::InvalidError
      end
    end
  end


  describe 'post a new image metadata' do
    it "should post a new image given its metadata" do
      EventMachine.synchrony do
        sample = {
            name: 'testsample2',
            architecture: 'arch',
            access: 'public',
            type: 'type',
            format: 'disk',
            store: 'store'
        }
        res = Metadata::API::Mongo.post_image(sample, 'mongo-test')
        res.must_be_instance_of Fixnum
        EventMachine.stop
      end
    end

    it "should return nil if image validation fails" do
      skip
    end
  end


  describe 'get all public images' do
    it "should return am array with all public images metadata" do
      EventMachine.synchrony do
        pub = Metadata::API::Mongo.get_public_images('mongo-test')
        pub.must_be_instance_of Array
        pub.each do |image|
          image['access'].must_equal 'public'
        end
        EventMachine.stop
      end
    end

    it "should return nil if there is no public image" do
      EventMachine.synchrony do
        # remove all images and insert one private
        images = Metadata::API::Mongo.configure_db('mongo-test', :coll => 'images')
        images.remove({})
        Metadata::API::Mongo.post_image({access: 'private'}, 'mongo-test')
        # try to find public images should fail
        pub = Metadata::API::Mongo.get_public_images('mongo-test')
        pub.must_be_instance_of NilClass
        EventMachine.stop
      end
    end
  end


  describe 'get an image by its id' do
    it "should return the image metadata with the given id" do
      EventMachine.synchrony do
        # capture the previous inserted sample image
        db = Metadata::API::Mongo.configure_db('mongo-test', :coll => 'images')
        sample = db.find({name: 'testsample'}).first
        id = sample['_id']
        # now find it by id
        img = Metadata::API::Mongo.get_image(id, 'mongo-test')
        img.must_be_instance_of BSON::OrderedHash
        img['name'].must_equal 'testsample'
        EventMachine.stop
      end
    end

    it "should return nil if image not found" do
      EventMachine.synchrony do
        img = Metadata::API::Mongo.get_image(1000, 'mongo-test')
        img.must_be_instance_of NilClass
        EventMachine.stop
      end
    end
  end


  describe 'delete an image by its id' do
    it "should delete an image with the given id and return its metadata" do
      EventMachine.synchrony do
        # capture the previous inserted sample image
        db = Metadata::API::Mongo.configure_db('mongo-test', :coll => 'images')
        sample = db.find({name: 'testsample'}).first
        id = sample['_id']
        # now delete it by id
        img = Metadata::API::Mongo.delete_image(id, 'mongo-test')
        img.must_be_instance_of BSON::OrderedHash
        img['_id'].must_equal id
        EventMachine.stop
      end
    end

    it "should return nil if image not found" do
      EventMachine.synchrony do
        img = Metadata::API::Mongo.delete_image(1000, 'mongo-test')
        img.must_be_instance_of NilClass
        EventMachine.stop
      end
    end
  end


  describe 'update an image by its id and new metadata' do
    it "should update an image metadata and return it" do
      EventMachine.synchrony do
        up = {
            name: 'Ubuntu xyz',
            architecture: 'i386',
            a: 'y'
        }
        # retrieve sample image id and its metadata
        db = Metadata::API::Mongo.configure_db('mongo-test', :coll => 'images')
        sample = db.find({name: 'testsample'}).first
        id = sample['_id']
        # update it with up
        update = Metadata::API::Mongo.put_image(id, up, 'mongo-test')
        update.must_be_instance_of BSON::OrderedHash
        update.must_equal sample.merge!(JSON.parse(up.to_json))
        EventMachine.stop
      end
    end

    it "should return nil if image validation fails" do
      skip
    end
  end

  
  describe 'fill protected fields at insert time' do
    it "should set the status to locked" do
      fill = @sample.merge({:status => 'locked'})
      filled = Metadata::API::Mongo.protected_fields(fill)
      filled[:status].must_equal 'locked'
    end
  end

  describe 'set the status of an image' do
    it "should set the status of an image given its id and the wanted status" do
      EventMachine.synchrony do
        # capture the previous inserted sample image
        db = Metadata::API::Mongo.configure_db('mongo-test', :coll => 'images')
        sample = db.find({name: 'testsample'}).first
        id = sample['_id']
        # now set it status
        Metadata::API::Mongo.set_status(id, 'locked')
        sample = db.find({:_id => id})
        sample.first['status'].must_equal 'locked'
        EventMachine.stop
      end
      
    end
  end
end
