require File.expand_path("../spec_helper", __FILE__)

include Cbolt::Registry::Backends

describe "Cbolt::Registry::Server" do

  let(:parse_opts) { {symbolize_names: true} }

  let(:valid_post) { {image: {name: 'server_spec',
                              architecture: 'i386',
                              access: 'public'}} }

  let(:invalid_post) { {image: {name: 'server_spec',
                                architecture: 'i386',
                                access: 'this is not valid'}} }

  let(:valid_update) { {image: {architecture: 'x86_64'}} }

  let(:invalid_update) { {image: {architecture: 'this is not valid'}} }

  $inserted_images_id = []

  def images_from(last_response, single_image = false)
    response = JSON.parse(last_response.body, parse_opts)
    single_image ? response[:image] : response[:images]
  end

  def message_from(last_response)
    JSON.parse(last_response.body, parse_opts)[:message]
  end

  before(:each) do
    post '/images', valid_post.to_json
    @valid_id = JSON.parse(last_response.body, parse_opts)[:image][:_id]
    $inserted_images_id << @valid_id
  end

  after(:all) do
    $inserted_images_id.each { |id| delete("/images/#{id}") }
  end

  describe "GET on /images" do
    it "should return an array of images" do
      get '/images'
      last_response.should be_ok
      images = images_from(last_response)
      images.should be_instance_of Array
    end

    it "should return only brief information fields" do
      get '/images'
      images = images_from(last_response)
      images.each { |img| (img.keys - Base::BRIEF).should be_empty }
    end

    it "should filter results" do
      get "/images?name=#{valid_post[:image][:name]}"
      images = images_from(last_response)
      images.each { |img| img[:name].should == valid_post[:image][:name] }
    end
  end

  describe "GET on /images/detail" do
    it "should return an array of images" do
      get '/images/detail'
      images = images_from(last_response)
      images.should be_instance_of Array
    end

    it "should return only detail information fields" do
      get '/images/detail'
      images = images_from(last_response)
      images.each { |img| (img.keys & Base::DETAIL_EXC).should be_empty }
    end
    it "should filter results" do
      get "/images?name=#{valid_post[:image][:name]}"
      last_response.should be_ok
      images = images_from(last_response)
      images.each { |img| img[:name].should == valid_post[:image][:name] }
    end
  end

  describe "GET on /images/:id" do
    it "should return a hash with the given image meta" do
      get "/images/#{@valid_id}"
      image = images_from(last_response, true)
      image.should be_instance_of Hash
      image[:name].should == "server_spec"
    end

    it "should return only detail information fields" do
      get "/images/#{@valid_id}"
      image = images_from(last_response, true)
      (image.keys & Base::DETAIL_EXC).should be_empty
    end

    it "should raise a 404 error if image not found" do
      get "/images/fake_id"
      last_response.should_not be_ok
      last_response.status.should == 404
      message_from(last_response).should_not be_nil
    end
  end

  describe "POST on /images" do
    it "should create a new image and return its metadata" do
      post '/images', valid_post.to_json
      last_response.should be_ok

      image = images_from(last_response, true)
      image.should be_instance_of Hash
      image[:_id].should be_a String
      image[:name].should == valid_post[:image][:name]
      $inserted_images_id << image[:_id]
    end

    it "should raise a 400 error if meta validation fails" do
      post '/images', invalid_post.to_json
      last_response.should_not be_ok
      last_response.status.should == 400
      message_from(last_response).should_not be_nil
    end
  end

  describe "PUT on /images/:id" do
    it "should update an existing image metadata" do
      put "/images/#{@valid_id}", valid_update.to_json
      last_response.should be_ok

      image = images_from(last_response, true)
      image.should be_instance_of Hash
      image[:_id].should be_a String
      image[:architecture].should == valid_update[:image][:architecture]
    end

    it "should raise a 400 error if meta validation fails" do
      put "/images/#{@valid_id}", invalid_update.to_json
      last_response.should_not be_ok
      last_response.status.should == 400
      message_from(last_response).should_not be_nil
    end
  end

  describe "DELETE on /images/:id" do
    it "should delete an image metadata" do
      delete "/images/#{@valid_id}"
      last_response.should be_ok

      image = images_from(last_response, true)
      image.should be_instance_of Hash
      image[:_id].should == @valid_id

      get "/images/#{@valid_id}"
      last_response.body.should =~ /No image found/
    end

    it "should raise a 404 error if image not found" do
      delete "/images/fake_id"
      last_response.should_not be_ok
      last_response.status.should == 404
      message_from(last_response).should_not be_nil
    end
  end
end

