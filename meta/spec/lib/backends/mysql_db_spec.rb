require "spec_helper"

include Visor::Common::Exception
include Visor::Registry::Backends

module Visor::Registry::Backends
  describe MySQL do

    let(:conn) { MySQL.connect :db => 'visor_test' }

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
        obj = MySQL.connect db: 'visor_test'
        obj.db.should == 'visor_test'
        obj.host.should == MySQL::DEFAULT_HOST
      end

      it "should instantiate a new object trougth URI" do
        uri = "mysql://:@#{MySQL::DEFAULT_HOST}:#{MySQL::DEFAULT_PORT}/visor_test"
        obj = MySQL.connect uri: uri
        obj.db.should == 'visor_test'
        obj.host.should == MySQL::DEFAULT_HOST
      end
    end

    describe "#connection" do
      it "should return a connection to the dabatase" do
        conn.connection.should be_an_instance_of Mysql2::Client
      end
    end

    describe "#get_public_images" do
      it "should return an array with all public images meta" do
        pub = conn.get_public_images
        pub.should be_an_instance_of Array
        pub.each { |img| img[:access].should == 'public' }
      end

      it "should return extra fields" do
        conn.post_image(@sample.merge(extra_field: 'value'))
        returned = 0
        pub = conn.get_public_images
        pub.each { |img| returned = 1 if img[:extra_field] }
        returned.should == 1
      end

      it "should return only brief information" do
        pub = conn.get_public_images(true)
        pub.each { |img| (img.keys - Base::BRIEF).should be_empty }
      end

      it "should sort results if asked to" do
        conn.post_image(@sample)
        pub = conn.get_public_images(false, sort: 'architecture', dir: 'desc')
        pub.first[:architecture].should == 'x86_64'
      end

      it "should raise an NotFound exception if there are no public images" do
        conn.delete_all!
        lambda { conn.get_public_images }.should raise_error(NotFound, /public/)
      end
    end

    describe "#get_image" do
      before(:each) do
        @id = conn.get_public_images.first[:_id]
      end

      it "should return a hash with the asked image meta" do
        img = conn.get_image(@id)
        img.should be_a(Hash)
        img[:_id].should == @id
      end

      it "should return only detail information fields" do
        img = conn.get_image(@id)
        (img.keys & Base::DETAIL_EXC).should be_empty
      end

      it "should return extra fields" do
        image = conn.post_image(@sample.merge(extra_field: 'value'))
        image[:extra_field].should == 'value'
      end

      it "should raise an NotFound exception if image not found" do
        fake_id = 0
        lambda { conn.get_image(fake_id) }.should raise_error(NotFound, /id/)
      end
    end

    describe "#delete_image" do
      it "should return a hash with the deleted image meta" do
        id = conn.get_public_images.first[:_id]
        img = conn.delete_image(id)
        img.should be_a(Hash)
        img[:_id].should == id
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        lambda { conn.delete_image(fake_id) }.should raise_error(NotFound, /id/)
      end
    end

    describe "#delete_all!" do
      it "should delete all records in images and counters collection" do
        conn.delete_all!
        lambda { conn.get_public_images }.should raise_error(NotFound, /public/)
      end
    end

    describe "#post_image" do
      it "should post an image and return it" do
        image = conn.post_image(@sample, method: 1)
        image.should be_a(Hash)
        image[:name].should == @sample[:name]
      end

      it "should post an image with additional fields" do
        image = conn.post_image(@sample.merge(extra_field: 'value'))
        image[:extra_field].should == 'value'
      end

      it "should raise an exception if meta validation fails" do
        img = @sample.merge(:status => 'status can not be set')
        lambda { conn.post_image(img) }.should raise_error(ArgumentError, /status/)
      end
    end

    describe "#put_image" do
      before(:each) do
        @id = conn.get_public_images.first[:_id]
      end

      it "should return a hash with updated image" do
        update = {:name => 'updated', :type => 'none'}
        img = conn.put_image(@id, update)
        img.should be_a(Hash)
        img[:name].should == 'updated'
        img[:type].should == 'none'
      end

      it "should update extra fields too" do
        id = conn.post_image(@sample.merge(extra_field: 'value'))[:_id]
        image = conn.put_image(id, extra_field: 'new value')
        image[:extra_field].should == 'new value'
      end

      it "should raise an exception if meta validation fails" do
        update = {:status => 'status can not be set'}
        lambda { conn.put_image(@id, update) }.should raise_error(ArgumentError, /status/)
      end
    end
  end
end
