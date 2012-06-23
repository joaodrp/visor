require "spec_helper"

describe Visor::Image::Meta do

  let(:meta) { Visor::Image::Meta.new }
  let(:not_found) { Visor::Common::Exception::NotFound }
  let(:invalid) { Visor::Common::Exception::Invalid }
  let(:address) {"0.0.0.0:0000"}

  let(:valid_post) { {name: 'client_spec', architecture: 'i386', access: 'public'} }
  let(:invalid_post) { {name: 'client_spec', architecture: 'i386', access: 'invalid'} }

  let(:valid_update) { {architecture: 'x86_64'} }
  let(:invalid_update) { {architecture: 'invalid'} }

  inserted = []

  before(:all) do
    EM.synchrony do
      inserted << meta.post_image(valid_post, address)[:_id]
      inserted << meta.post_image(valid_post.merge(architecture: 'x86_64'), address)[:_id]
      EM.stop
    end
  end

  after(:all) do
    EM.synchrony do
      inserted.each { |id| meta.delete_image(id) }
      EM.stop
    end
  end

  describe "#initialize" do
    it "should create a new meta api object with default parameters" do
      meta.host.should == Visor::Image::Meta::DEFAULT_HOST
      meta.port.should == Visor::Image::Meta::DEFAULT_PORT
    end

    it "should create a new meta api object with custom parameters" do
      custom = Visor::Image::Meta.new(host: '0.0.0.0', port: 1111)
      custom.host.should == '0.0.0.0'
      custom.port.should == 1111
    end
  end

  describe "#get_images" do
    it "should return an array of hashes" do
      EM.synchrony do
        res = meta.get_images
        res.should be_a Array
        res.each { |h| h.should be_a Hash }
        EM.stop
      end
    end

    it "should filter results by parameter" do
      EM.synchrony do
        res = meta.get_images(architecture: 'i386')
        res.each { |h| h[:architecture].should == 'i386' }
        EM.stop
      end
    end

    it "should sort results by parameter and direction" do
      EM.synchrony do
        pub = meta.get_images(sort: 'architecture', dir: 'desc')
        #pub.first[:architecture].should == 'x86_64'
        pub = meta.get_images(sort: 'architecture', dir: 'asc')
        pub.first[:architecture].should == 'i386'
        EM.stop
      end
    end

    it "should raise if no matches found" do
      EM.synchrony do
        lambda { meta.get_images(:name => 'fake') }.should raise_error not_found
        EM.stop
      end
    end
  end

  describe "#get_images_detail" do
    it "should return an array of hashes" do
      EM.synchrony do
        res = meta.get_images
        res.should be_a Array
        res.each { |h| h.should be_a Hash }
        EM.stop
      end
    end

    it "should filter results by parameter" do
      EM.synchrony do
        res = meta.get_images(architecture: 'x86_64')
        res.each { |h| h[:architecture].should == 'x86_64' }
        EM.stop
      end
    end

    it "should sort results by parameter and direction" do
      EM.synchrony do
        pub = meta.get_images(sort: 'architecture', dir: 'desc')
        #pub.first[:architecture].should == 'x86_64'
        pub = meta.get_images(sort: 'architecture', dir: 'asc')
        pub.first[:architecture].should == 'i386'
        EM.stop
      end
    end

    it "should raise if no matches found" do
      EM.synchrony do
        lambda { meta.get_images(:name => 'fake') }.should raise_error not_found
        EM.stop
      end
    end
  end

  describe "#get_image" do
    before(:each) do
      EM.synchrony do
        @id = meta.post_image(valid_post, address)[:_id]
        inserted << @id
        @image = meta.get_image(@id)
        EM.stop
      end
    end

    it "should return a hash" do
      @image.should be_a Hash
    end

    it "should return the asked image metadata" do
      @image[:_id].should == @id
    end

    it "should raise an exception if image not found" do
      fake_id = 0
      EM.synchrony do
        lambda { meta.get_image(fake_id) }.should raise_error not_found
        EM.stop
      end
    end
  end

  describe "#delete_image" do
    before(:each) do
      EM.synchrony do
        @id    = meta.post_image(valid_post, address)[:_id]
        @image = meta.delete_image(@id)
        EM.stop
      end
    end

    it "should return a hash" do
      @image.should be_a Hash
    end

    it "should return the deleted image metadata" do
      @image[:_id].should == @id
    end

    it "should trully delete that image from database" do
      EM.synchrony do
        lambda { meta.get_image(@id) }.should raise_error not_found
        EM.stop
      end
    end

    it "should raise an exception if image not found" do
      fake_id = 0
      EM.synchrony do
        lambda { meta.delete_image(fake_id) }.should raise_error not_found
        EM.stop
      end
    end
  end

  describe "#post_image" do
    before(:each) do
      EM.synchrony do
        @image = meta.post_image(valid_post, address)
        inserted << @image[:_id]
        EM.stop
      end
    end

    it "should return a hash" do
      @image.should be_a Hash
    end

    it "should return posted image metadata" do
      @image[:_id].should be_a(String)
      @image[:access].should == valid_post[:access]
    end

    it "should raise an exception if meta validation fails" do
      EM.synchrony do
        lambda { meta.post_image(invalid_post, address) }.should raise_error invalid
        EM.stop
      end
    end
  end

  describe "#put_image" do
    before :each do
      EM.synchrony do
        @id = meta.post_image(valid_post, address)[:_id]
        inserted << @id
        @image = meta.put_image(@id, valid_update)
        EM.stop
      end
    end

    it "should return a hash" do
      @image.should be_a Hash
    end

    it "should return update image metadata" do
      @image[:_id].should == @id
      @image[:architecture].should == valid_update[:architecture]
    end

    it "should raise an exception if meta validation fails" do
      EM.synchrony do
        lambda { meta.put_image(@id, invalid_update) }.should raise_error invalid
        EM.stop
      end
    end
  end

end
