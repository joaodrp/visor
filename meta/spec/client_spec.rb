require File.expand_path("../spec_helper", __FILE__)

module Cbolt::Registry
  describe Client do

    include Cbolt::Registry

    let(:client) { Client.new }

    let(:valid_post) { {name: 'client_spec', architecture: 'i386', access: 'public'} }
    let(:invalid_post) { {name: 'client_spec', architecture: 'i386', access: 'invalid'} }

    let(:valid_update) { {architecture: 'x86_64'} }
    let(:invalid_update) { {architecture: 'invalid'} }

    @@inserted_images_id = []

    before(:each) do
      @@inserted_images_id << client.post_image(valid_post)[:_id]
      @@inserted_images_id << client.post_image(valid_post.merge(architecture: 'x86_64'))[:_id]
    end

    after(:all) do
      @@inserted_images_id.each { |id| client.delete_image(id) }
    end

    describe "#initialize" do
      it "should instantiate a new client with default options" do
        client.host.should == Client::DEFAULT_HOST
        client.port.should == Client::DEFAULT_PORT
        client.ssl.should be_false
      end

      it "should instantiate a new client with provided options" do
        c = Cbolt::Registry::Client.new('1.1.1.1', 1, true)
        c.host.should == '1.1.1.1'
        c.port.should == 1
        c.ssl.should be_true
      end
    end

    describe "#get_images" do
      before(:each) do
        @images = client.get_images_detail
      end

      it "should return an array" do
        @images.should be_a Array
      end

      it "should return all public images" do
        @images.each { |image| image[:access].should == 'public' }
      end

      it "should return an array" do
        @images.should be_a Array
      end

      it "should filter results if asked to" do
        pub = client.get_images(architecture: 'x86_64')
        pub.each { |img| img[:architecture].should == 'x86_64' }
      end

      it "should sort results if asked to" do
        pub = client.get_images(sort: 'architecture', dir: 'desc')
        pub.first[:architecture].should == 'x86_64'
        pub = client.get_images(sort: 'architecture', dir: 'asc')
        pub.first[:architecture].should == 'i386'
      end
    end

    describe "#get_images_detail" do
      before(:each) do
        @images = client.get_images_detail
      end

      it "should return an array" do
        @images.should be_a Array
      end

      it "should return all public images" do
        @images.each { |image| image[:access].should == 'public' }
      end

      it "should filter results if asked to" do
        pub = client.get_images_detail(architecture: 'x86_64')
        pub.each { |img| img[:architecture].should == 'x86_64' }
      end

      it "should sort results if asked to" do
        pub = client.get_images(sort: 'architecture', dir: 'desc')
        pub.first[:architecture].should == 'x86_64'
        pub = client.get_images(sort: 'architecture', dir: 'asc')
        pub.first[:architecture].should == 'i386'
      end
    end

    describe "#get_image" do
      before(:each) do
        @id = @@inserted_images_id.sample
        @image = client.get_image(@id)
      end

      it "should return a hash" do
        @image.should be_a Hash
      end

      it "should return the asked image metadata" do
        @image[:_id].should == @id
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        lambda { client.get_image(fake_id) }.should raise_error Cbolt::NotFound
      end
    end

    describe "#delete_image" do
      before(:each) do
        @id = client.post_image(valid_post)[:_id]
        @image = client.delete_image(@id)
      end

      it "should return a hash" do
        @image.should be_a Hash
      end

      it "should return the deleted image metadata" do
        @image[:_id].should == @id
      end

      it "should trully delete that image from database" do
        lambda { client.get_image(@id) }.should raise_error Cbolt::NotFound
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        lambda { client.delete_image(fake_id) }.should raise_error Cbolt::NotFound
      end
    end

    describe "#post_image" do
      before(:each) do
        @image = client.post_image(valid_post)
        @@inserted_images_id << @image[:_id]
      end

      it "should return a hash" do
        @image.should be_a Hash
      end

      it "should return posted image metadata" do
        @image[:_id].should be_a(String)
        @image[:access].should == valid_post[:access]
      end

      it "should raise an exception if meta validation fails" do
        lambda { client.post_image(invalid_post) }.should raise_error Cbolt::Invalid
      end
    end

    describe "#put_image" do
      before :each do
        @id = @@inserted_images_id.first
        @image = client.put_image(@id, valid_update)
      end

      it "should return a hash" do
        @image.should be_a Hash
      end

      it "should return update image metadata" do
        @image[:_id].should == @id
        @image[:architecture].should == valid_update[:architecture]
      end

      it "should raise an exception if meta validation fails" do
        lambda { client.put_image(@id, invalid_update) }.should raise_error Cbolt::Invalid
      end
    end
  end
end
