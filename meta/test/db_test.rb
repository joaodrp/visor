require 'minitest/autorun'
require 'mongo'
require 'colorific'
require File.dirname(__FILE__) + '/../db/mongo'


describe API::Mongo do

  before do
    # configure a mongo database to run these tests
    db = Mongo::Connection.new.db('mongo-test')
    @coll = db.collection('images')
    # insert a sample image
    sample = {
        name: 'testsample',
        architecture: 'arch',
        access: 'public',
        type: 'type',
        disk: 'disk',
        store: 'store'
    }
    @coll.insert(sample)
  end

  after do
    # drop the collection and all test operations done on it
    @coll.drop
  end

  describe 'configure database' do
    it "should create a database connection and return the db object" do
      EventMachine.synchrony do
        db = API::Mongo.configure_db(nil, 'mongo-test')
        db.must_be_instance_of EM::Mongo::Database
        EventMachine.stop
      end
    end

    it "should create a database connection to a specific collection" do
      EventMachine.synchrony do
        coll = API::Mongo.configure_db('images', 'mongo-test')
        coll.must_be_instance_of EM::Mongo::Collection
        EventMachine.stop
      end
    end
  end

  describe 'configure counters' do
    it "should configure the counters collection" do
      EventMachine.synchrony do
        API::Mongo.configure_counters('mongo-test')
        coll = API::Mongo.configure_db('counters', 'mongo-test')
        id = coll.find[0]['count']
        id.must_be_instance_of Fixnum
        EventMachine.stop
      end
    end
  end

  describe 'validate data' do
    # TODO
  end

  describe 'post a new image metadata' do
    it "should post a new image given its metadata" do
      EventMachine.synchrony do
        sample = {
            name: 'testsample2',
            architecture: 'arch',
            access: 'public',
            type: 'type',
            disk: 'disk',
            store: 'store'
        }
        res = API::Mongo.post_image(sample, 'mongo-test')
        res.must_be_instance_of Fixnum
        EventMachine.stop
      end
    end
  end

  describe 'get all public images' do
    it "should return am array with all public images metadata" do
      EventMachine.synchrony do
        pub = API::Mongo.get_public_images('mongo-test')
        pub.must_be_instance_of Array
        pub.each do |image|
          image['access'].must_equal 'public'
        end
        EventMachine.stop
      end
    end
  end

  describe 'get an image by its id' do
    it "should return an array with the image metadata with the given id" do
      EventMachine.synchrony do
        # capture the previous inserted sample image
        db = API::Mongo.configure_db('images', 'mongo-test')
        sample = db.find({name: 'testsample'}).first
        id = sample['_id']
        # now find it by id
        img = API::Mongo.get_image(id, 'mongo-test')
        img.must_be_instance_of Array
        img.first['name'].must_equal 'testsample'
        EventMachine.stop
      end
    end
  end

  describe 'delete an image by its id' do
    it "should delete an image with the given id and return its metadata" do
      EventMachine.synchrony do
        # capture the previous inserted sample image
        db = API::Mongo.configure_db('images', 'mongo-test')
        sample = db.find({name: 'testsample'}).first
        id = sample['_id']
        # now delete it by id
        img = API::Mongo.delete_image(id, 'mongo-test')
        img.must_be_instance_of Array
        img.size.must_equal 1
        img.first['_id'].must_equal id
        EventMachine.stop
      end
    end

  end
end
