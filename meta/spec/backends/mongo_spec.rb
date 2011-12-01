require "spec_helper"

include Cbolt::Backends

module Cbolt::Backends
  describe MongoDB do
    # TODO: Test GET's with query parameters
    before(:each) do
      @conn = MongoDB.connect :db => 'mongo-test'
      @sample = {
          :name => 'testsample',
          :architecture => 'i386',
          :access => 'public',
          :format => 'iso'
      }
      @sample2 = {
          :name => 'xyz',
          :architecture => 'x86_64',
          :access => 'public',
          :type => 'kernel'
      }
      @conn.post_image(@sample)
    end

    after(:each) do
      @conn.connection(:images).remove
    end


    describe "#initialize" do
      it "should instantiate a new object" do
        @conn.db.should == 'mongo-test'
        @conn.host.should == MongoDB::MONGO_IP
      end
    end

    describe "#connection" do
      it "should return a connection to the dabatase" do
        @conn.connection.should be_an_instance_of Mongo::DB
      end
      it "should return a collection" do
        @conn.connection(:images).should be_an_instance_of Mongo::Collection
      end
    end

    describe "#get_public_images" do
      it "should return an array with all public images" do
        pub = @conn.get_public_images
        pub.should be_an_instance_of Array
        pub.each { |img| img['access'].should == 'public' }
      end

      it "should raise an exception if there are no public images" do
        @conn.delete_all!
        l = lambda { @conn.get_public_images }
        l.should raise_error(Cbolt::NotFound, /public/)
      end

      it "should return only brief information" do
        pub = @conn.get_public_images(true)
        pub.should be_an_instance_of Array
        pub.each { |img| (img.keys & MongoDB::BRIEF).should be_empty }
      end
    end

    describe "#get_image" do
      it "should return a bson hash with the asked image" do
        @conn.connection(:images).insert(@sample)
        id = @conn.get_public_images.first['_id']
        img = @conn.get_image(id)
        img.should be_instance_of BSON::OrderedHash
        img['_id'].should == id
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        l = lambda { @conn.get_image(fake_id) }
        l.should raise_error(Cbolt::NotFound, /id/)
      end
    end

    describe "#delete_image" do
      it "should return a bson hash with the deleted image" do
        id = @conn.get_public_images.first['_id']
        img = @conn.delete_image(id)
        img.should be_instance_of BSON::OrderedHash
        img['_id'].should == id
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        l = lambda { @conn.delete_image(fake_id) }
        l.should raise_error(Cbolt::NotFound, /id/)
      end
    end

    describe "#delete_all!" do
      it "should delete all records in images and counters collection" do
        @conn.delete_all!
        @conn.connection(:images).find.to_a.should == []
        @conn.connection(:counters).find.to_a.should == []
      end
    end

    describe "#post_image" do
      it "should post an image and return its id" do
        @conn.post_image(@sample2).should be_instance_of Fixnum
      end

      it "should raise an exception if meta validation fails" do
        img = @sample2.merge(:status => 'status can not be set')
        l = lambda { @conn.post_image(img) }
        l.should raise_error(ArgumentError, /status/)
      end
    end

    describe "#put_image" do
      it "should return a bson hash with updated image" do
        id = @conn.get_public_images.first['_id']
        update = {:name => 'updated', :type => 'none'}
        img = @conn.put_image(id, update)
        img.should be_instance_of BSON::OrderedHash
        img['name'].should == 'updated'
        img['type'].should == 'none'
      end

      it "should raise an exception if meta validation fails" do
        id = @conn.get_public_images.first['_id']
        update = {:status => 'status can not be set'}
        l = lambda { @conn.put_image(id, update) }
        l.should raise_error(ArgumentError, /status/)
      end
    end
  end
end
