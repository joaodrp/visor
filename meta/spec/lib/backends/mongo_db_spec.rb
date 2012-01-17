require "spec_helper"

include Visor::Common::Exception
include Visor::Meta::Backends

module Visor::Meta::Backends
  describe MongoDB do

    let(:conn) { MongoDB.connect uri: 'mongodb://:@127.0.0.1:27017/visor_test' }

    before(:each) do
      conn.post_image ({:name => 'testsample',
                        :architecture => 'i386',
                        :access => 'public',
                        :format => 'iso'})

      @sample = {:name => 'xyz',
                 :architecture => 'x86_64',
                 :access => 'public',
                 :type => 'kernel'}
    end

    after(:all) do
      conn.delete_all!
    end

    describe "#connect" do
      it "should instantiate a new object trougth options" do
        obj = conn
        obj.db.should == 'visor_test'
        obj.host.should == MongoDB::DEFAULT_HOST
      end

      it "should instantiate a new object trougth URI" do
        uri = "mongodb://:@#{MongoDB::DEFAULT_HOST}:#{MongoDB::DEFAULT_PORT}/visor_test"
        obj = MongoDB.connect uri: uri
        obj.db.should == 'visor_test'
        obj.host.should == MongoDB::DEFAULT_HOST
      end
    end

    describe "#connection" do
      it "should return a collection connection" do
        conn.connection.should be_a Mongo::Collection
      end
    end

    describe "#get_public_images" do
      it "should return an array with all public images meta" do
        pub = conn.get_public_images
        pub.should be_a Array
        pub.each { |img| img['access'].should == 'public' }
      end

      it "should return only brief information" do
        pub = conn.get_public_images(true)
        pub.each { |img| (img.keys & MongoDB::BRIEF).should be_empty }
      end

      it "should filter results if asked to" do
        pub = conn.get_public_images(false, architecture: 'i386')
        pub.each { |img| img['architecture'].should == 'i386' }
      end

      it "should sort results if asked to" do
        conn.post_image @sample
        pub = conn.get_public_images(false, sort: 'architecture', dir: 'desc')
        pub.first['architecture'].should == 'x86_64'
      end

      it "should raise an NotFound exception if there are no public images" do
        conn.delete_all!
        lambda { conn.get_public_images }.should raise_error(NotFound, /public/)
      end
    end

    describe "#get_image" do
      before(:each) do
        @id = conn.get_public_images.first['_id']
      end

      it "should return a bson hash with the asked image" do
        img = conn.get_image(@id)
        img.should be_a BSON::OrderedHash
        img['_id'].should == @id
      end

      it "should return only detail information fields" do
        img = conn.get_image(@id)
        (img.keys & Base::DETAIL_EXC).should be_empty
      end

      it "should raise an NotFound exception if image not found" do
        fake_id = 0
        lambda { conn.get_image(fake_id) }.should raise_error(NotFound, /id/)
      end
    end

    describe "#delete_image" do
      it "should return a bson hash with the deleted image" do
        id = conn.get_public_images.first['_id']
        img = conn.delete_image(id)
        img.should be_a BSON::OrderedHash
        img['_id'].should == id
      end

      it "should raise an NotFound exception if image not found" do
        fake_id = 0
        lambda { conn.get_image(fake_id) }.should raise_error(NotFound, /id/)
      end
    end

    describe "#delete_all!" do
      it "should delete all records in images and counters collection" do
        conn.delete_all!
        conn.connection.find.to_a.should == []
      end
    end

    describe "#post_image" do
      it "should post an image and return its meta" do
        image = conn.post_image(@sample)
        image.should be_a(Hash)
        image['name'].should == @sample[:name]
      end

      it "should raise an ArgumentError exception if meta validation fails" do
        img = @sample.merge(:_id => 'cant define _id')
        lambda { conn.post_image(img) }.should raise_error(ArgumentError, /_id/)
      end
    end

    describe "#put_image" do
      before(:each) do
        @id = conn.get_public_images.first['_id']
      end

      it "should return a bson hash with updated image meta" do
        update = {:name => 'updated', :type => 'none'}
        img = conn.put_image(@id, update)
        img.should be_a BSON::OrderedHash
        img['name'].should == 'updated'
        img['type'].should == 'none'
      end

      it "should raise an ArgumentError exception if meta validation fails" do
        update = {:uri => 'cant define uri'}
        lambda { conn.put_image(@id, update) }.should raise_error(ArgumentError, /uri/)
      end
    end
  end
end
