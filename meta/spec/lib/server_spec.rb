require "spec_helper"

include Visor::Meta::Backends

describe Visor::Meta::Server do

  let(:parse_opts) { {symbolize_names: true} }

  let(:valid_post) { {image: {name: 'server_spec', architecture: 'i386'}} }
  let(:invalid_post) { {image: {name: 'server_spec', architecture: 'i386', access: 'invalid'}} }

  let(:valid_update) { {image: {architecture: 'x86_64'}} }
  let(:invalid_update) { {image: {architecture: 'this is not valid'}} }

  inserted_ids = []

  def images_from(last_response, single_image = false)
    response = JSON.parse(last_response.body, parse_opts)
    single_image ? response[:image] : response[:images]
  end

  def message_from(last_response)
    JSON.parse(last_response.body, parse_opts)[:message]
  end

  def delete_all
    get '/images'
    images = images_from(last_response)
    images.each { |image| delete "/images/#{image[:_id]}" }
  end

  before(:each) do
    post '/images', valid_post.to_json
    @valid_id = JSON.parse(last_response.body, parse_opts)[:image][:_id]
    inserted_ids << @valid_id
  end

  after(:all) do
    inserted_ids.each { |id| delete("/images/#{id}") }
  end

  describe "GET on /images" do
    before(:each) do
      get '/images'
      last_response.should be_ok
    end

    it "should return an array" do
      images = images_from(last_response)
      images.should be_a Array
    end

    it "should return only brief information fields" do
      images = images_from(last_response)
      images.each { |img| (img.keys - Base::BRIEF).should be_empty }
    end

    it "should filter results" do
      get "/images?name=#{valid_post[:image][:name]}"
      images = images_from(last_response)
      images.each { |img| img[:name].should == valid_post[:image][:name] }
    end

    it "should raise an 404 error if no public images found" do
      delete_all
      get '/images'
      last_response.status.should == 404
      message_from(last_response) =~ /no image found/
    end
  end

  describe "GET on /images/detail" do
    before(:each) do
      get '/images/detail'
      last_response.should be_ok
    end

    it "should return an array" do
      images = images_from(last_response)
      images.should be_a Array
    end

    it "should return only detail information fields" do
      images = images_from(last_response)
      images.each { |img| (img.keys & Base::DETAIL_EXC).should be_empty }
    end

    it "should filter results" do
      get "/images?name=#{valid_post[:image][:name]}"
      images = images_from(last_response)
      images.each { |img| img[:name].should == valid_post[:image][:name] }
    end

    it "should raise an 404 error if no public images found" do
      delete_all
      get '/images/detail'
      last_response.status.should == 404
      message_from(last_response) =~ /no image found/
    end
  end

  describe "GET on /images/:id" do
    before(:each) do
      get "/images/#{@valid_id}"
      last_response.should be_ok
    end

    it "should return a hash with the image meta" do
      image = images_from(last_response, true)
      image.should be_a Hash
      image[:name].should == "server_spec"
    end

    it "should return only detail information fields" do
      image = images_from(last_response, true)
      (image.keys & Base::DETAIL_EXC).should be_empty
    end

    it "should raise a 404 error if image not found" do
      get "/images/fake_id"
      last_response.status.should == 404
      message_from(last_response) =~ /no image found/
    end
  end

  describe "POST on /images" do
    it "should create a new image and return its metadata" do
      post '/images', valid_post.to_json
      last_response.should be_ok
      image = images_from(last_response, true)
      image[:_id].should be_a String
      image[:name].should == valid_post[:image][:name]
      inserted_ids << image[:_id]
    end

    it "should raise a 400 error if meta validation fails" do
      post '/images', invalid_post.to_json
      last_response.status.should == 400
      message_from(last_response) =~ /fields/
    end

    it "should raise a 404 error if referenced an invalid kernel/ramdisk image" do
      post '/images', valid_post.merge(kernel: "fake_id").to_json
      message_from(last_response) =~ /no image found/
    end
  end

  describe "PUT on /images/:id" do
    it "should update an existing image metadata and return it" do
      put "/images/#{@valid_id}", valid_update.to_json
      last_response.should be_ok
      image = images_from(last_response, true)
      image[:_id].should be_a String
      image[:architecture].should == valid_update[:image][:architecture]
    end

    it "should raise a 400 error if meta validation fails" do
      put "/images/#{@valid_id}", invalid_update.to_json
      last_response.status.should == 400
      message_from(last_response) =~ /fields/
    end

    it "should raise a 404 error if referenced an invalid kernel/ramdisk image" do
      put '/images', valid_update.merge(kernel: "fake_id").to_json
      message_from(last_response) =~ /no image found/
    end
  end

  describe "DELETE on /images/:id" do

    it "should delete an image metadata" do
      delete "/images/#{@valid_id}"
      last_response.should be_ok

      image = images_from(last_response, true)
      image.should be_a Hash
      image[:_id].should == @valid_id

      get "/images/#{@valid_id}"
      last_response.body.should =~ /No image found/
    end

    it "should raise a 404 error if image not found" do
      delete "/images/fake_id"
      last_response.status.should == 404
      message_from(last_response) =~ /No image found/
    end
  end

  describe "Operation on a not implemented path" do
    after(:each) do
      last_response.status.should == 404
      message_from(last_response) =~ /Invalid operation or path/
    end

    it "should raise a 404 error for a GET request" do
      get "/fake"
    end

    it "should raise a 404 error for a POST request" do
      post "/fake"
    end

    it "should raise a 404 error for a PUT request" do
      put "/fake"
    end

    it "should raise a 404 error for a POST request" do
      delete "/fake"
    end
  end

end

