require File.expand_path("../../spec_helper", __FILE__)

include Visor::Common::Exception
include Visor::Registry::Backends

module Visor::Registry::Backends
  describe MongoDB do

    let(:conn) { MongoDB.connect db: 'visor_test' }

    before(:each) do
      sample = {
          :name => 'testsample',
          :architecture => 'i386',
          :access => 'public',
          :format => 'iso'
      }

      conn.post_image(sample)

      @sample = {
          :name => 'xyz',
          :architecture => 'x86_64',
          :access => 'public',
          :type => 'kernel'
      }
    end

    after(:all) do
      conn.connection.remove()
    end


    describe "#initialize" do
      it "should instantiate a new object" do
        conn.db.should == 'visor_test'
        conn.host.should == MongoDB::DEFAULT_HOST
      end
    end

    describe "#connection" do
      it "should return a collection connection" do
        conn.connection.should be_a Mongo::Collection
      end
    end

    describe "#get_public_images" do
      it "should return an array with all public images" do
        pub = conn.get_public_images
        pub.should be_a Array
        pub.each { |img| img['access'].should == 'public' }
      end

      it "should return only brief information" do
        pub = conn.get_public_images(true)
        pub.should be_a Array
        pub.each { |img| (img.keys & MongoDB::BRIEF).should be_empty }
      end

      it "should filter results if asked to" do
        pub = conn.get_public_images(false, architecture: 'i386')
        pub.should be_a Array
        pub.each { |img| img['architecture'].should == 'i386' }
      end

      it "should sort results if asked to" do
        conn.connection.insert(@sample)
        pub = conn.get_public_images(false, sort: 'architecture', dir: 'desc')
        pub.should be_a Array
        pub.first['architecture'].should == 'x86_64'
      end

      it "should raise an exception if there are no public images" do
        conn.delete_all!
        l = lambda { conn.get_public_images }
        l.should raise_error(NotFound, /public/)
      end
    end

    describe "#get_image" do
      it "should return a bson hash with the asked image" do
        conn.connection.insert(@sample)
        id = conn.get_public_images.first['_id']
        img = conn.get_image(id)
        img.should be_a BSON::OrderedHash
        img['_id'].should == id
      end

      it "should return only detail information fields" do
        conn.connection.insert(@sample)
        id = conn.get_public_images.first['_id']
        img = conn.get_image(id)
        (img.keys & Base::DETAIL_EXC).should be_empty
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        l = lambda { conn.get_image(fake_id) }
        l.should raise_error(NotFound, /id/)
      end
    end

    describe "#delete_image" do
      it "should return a bson hash with the deleted image" do
        id = conn.get_public_images.first['_id']
        img = conn.delete_image(id)
        img.should be_a BSON::OrderedHash
        img['_id'].should == id
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        l = lambda { conn.delete_image(fake_id) }
        l.should raise_error(NotFound, /id/)
      end
    end

    describe "#delete_all!" do
      it "should delete all records in images and counters collection" do
        conn.delete_all!
        conn.connection.find.to_a.should == []
      end
    end

    describe "#post_image" do
      it "should post an image and return it" do
        image = conn.post_image(@sample)
        image.should be_a(Hash)
        image['name'].should == @sample[:name]
      end

      it "should raise an exception if meta validation fails" do
        img = @sample.merge(:status => 'status can not be set')
        l = lambda { conn.post_image(img) }
        l.should raise_error(ArgumentError, /status/)
      end
    end

    describe "#put_image" do
      it "should return a bson hash with updated image" do
        id = conn.get_public_images.first['_id']
        update = {:name => 'updated', :type => 'none'}
        img = conn.put_image(id, update)
        img.should be_a BSON::OrderedHash
        img['name'].should == 'updated'
        img['type'].should == 'none'
      end

      it "should raise an exception if meta validation fails" do
        id = conn.get_public_images.first['_id']
        update = {:status => 'status can not be set'}
        l = lambda { conn.put_image(id, update) }
        l.should raise_error(ArgumentError, /status/)
      end
    end
  end
end
