require "spec_helper"

module Visor::Meta
  describe Api do

    include Visor::Meta
    include Visor::Common::Exception

    let(:not_found) { Visor::Common::Exception::NotFound }
    let(:invalid) { Visor::Common::Exception::Invalid }
    
    let(:valid_post) { {name: 'Api_spec', architecture: 'i386', access: 'public'} }
    let(:invalid_post) { {name: 'Api_spec', architecture: 'i386', access: 'invalid'} }

    let(:valid_update) { {architecture: 'x86_64'} }
    let(:invalid_update) { {architecture: 'invalid'} }

    inserted = []

    before(:each) do
      inserted << Api.add_image(valid_post)[:_id]
      inserted << Api.add_image(valid_post)[:_id]
      inserted << Api.add_image(valid_post.merge(architecture: 'x86_64'))[:_id]
    end

    after(:all) do
      inserted.each { |id| Api.delete_image(id) }
    end

    describe "#get_images" do
      before(:each) do
        @images = Api.get_images
      end

      it "should return an array" do
        @images.should be_a Array
      end

      it "should filter results if asked to" do
        pub = Api.get_images(architecture: 'x86_64')
        pub.each { |img| img[:architecture].should == 'x86_64' }
      end

      it "should sort results if asked to" do
        pub = Api.get_images(sort: 'architecture', dir: 'desc')
        pub.first[:architecture].should == 'x86_64'
        pub = Api.get_images(sort: 'architecture', dir: 'asc')
        pub.first[:architecture].should == 'i386'
      end
    end

    describe "#get_images_detail" do
      before(:each) do
        @images = Api.get_images_detail
      end

      it "should return an array" do
        @images.should be_a Array
      end

      it "should return all public images" do
        @images.each { |image| image[:access].should == 'public' }
      end

      it "should filter results if asked to" do
        pub = Api.get_images_detail(architecture: 'x86_64')
        pub.each { |img| img[:architecture].should == 'x86_64' }
      end

      it "should sort results if asked to" do
        pub = Api.get_images(sort: 'architecture', dir: 'desc')
        pub.first[:architecture].should == 'x86_64'
        pub = Api.get_images(sort: 'architecture', dir: 'asc')
        pub.first[:architecture].should == 'i386'
      end
    end

    describe "#get_image" do
      before(:each) do
        @id = inserted.sample
        @image = Api.get_image(@id)
      end

      it "should return a hash" do
        @image.should be_a Hash
      end

      it "should return the asked image metadata" do
        @image[:_id].should == @id
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        lambda { Api.get_image(fake_id) }.should raise_error not_found
      end
    end

    describe "#delete_image" do
      before(:each) do
        @id = Api.add_image(valid_post)[:_id]
        @image = Api.delete_image(@id)
      end

      it "should return a hash" do
        @image.should be_a Hash
      end

      it "should return the deleted image metadata" do
        @image[:_id].should == @id
      end

      it "should trully delete that image from database" do
        lambda { Api.get_image(@id) }.should raise_error not_found
      end

      it "should raise an exception if image not found" do
        fake_id = 0
        lambda { Api.delete_image(fake_id) }.should raise_error not_found
      end
    end

    describe "#add_image" do
      before(:each) do
        @image = Api.add_image(valid_post)
        inserted << @image[:_id]
      end

      it "should return a hash" do
        @image.should be_a Hash
      end

      it "should return posted image metadata" do
        @image[:_id].should be_a(String)
        @image[:access].should == valid_post[:access]
      end

      it "should raise an exception if meta validation fails" do
        lambda { Api.add_image(invalid_post) }.should raise_error invalid
      end
    end

    describe "#update_image" do
      before :each do
        @id = inserted.first
        @image = Api.update_image(@id, valid_update)
      end

      it "should return a hash" do
        @image.should be_a Hash
      end

      it "should return update image metadata" do
        @image[:_id].should == @id
        @image[:architecture].should == valid_update[:architecture]
      end

      it "should raise an exception if meta validation fails" do
        lambda { Api.update_image(@id, invalid_update) }.should raise_error invalid
      end
    end
  end
end
