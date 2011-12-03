require File.expand_path("../spec_helper", __FILE__)


include Cbolt::Backends

describe "Cbolt::Registry::Server" do

  let(:parse_opts) { {:symbolize_names => true} }

  let(:valid_meta) { {image: {name:         'server_spec',
                              architecture: 'i386',
                              access:       'public'}} }

  let(:valid_update) { {image: {architecture: 'x86_64'}} }

  before(:all) do
    post '/images', valid_meta.to_json
    @valid_id = JSON.parse(last_response.body, parse_opts)[:image][:_id]
  end

  after(:all) do
    delete "/images/#{@valid_id}"
  end

  describe "GET on /" do
    it "should return an array of images" do
      get '/'
      last_response.should be_ok
      response = JSON.parse(last_response.body, parse_opts)
      images   = response[:images]
      images.should be_instance_of Array
    end

    it "should return only brief information fields" do
      get '/'
      response = JSON.parse(last_response.body, parse_opts)
      images   = response[:images]
      images.each do |img|
        img.keys.sort.should == Backend::BRIEF.sort
      end
    end
  end

  describe "GET on /images" do
    it "should return an array of images" do
      get '/images'
      response = JSON.parse(last_response.body, parse_opts)
      images   = response[:images]
      images.should be_instance_of Array
    end

    it "should return only detail information fields" do
      get '/images'
      response = JSON.parse(last_response.body, parse_opts)
      images   = response[:images]
      images.each do |img|
        (img.keys & Backend::DETAIL_EXC).should be_empty
      end
    end
  end

  describe "GET on /images/:id" do
    it "should return a hash with the given image meta" do
      get "/images/#{@valid_id}"
      response = JSON.parse(last_response.body, parse_opts)
      image    = response[:image]
      image.should be_instance_of Hash
      image[:name].should == "server_spec"
    end

    it "should return only detail information fields" do
      get "/images/#{@valid_id}"
      response = JSON.parse(last_response.body, parse_opts)
      image    = response[:image]
      (image.keys & Backend::DETAIL_EXC).should be_empty
    end
  end

  describe "POST on /images" do
    it "should create a new image and return its metadata" do
      post '/images', valid_meta.to_json
      last_response.should be_ok

      response = JSON.parse(last_response.body, parse_opts)
      image    = response[:image]
      image.should be_instance_of Hash
      image[:_id].should be_instance_of Fixnum
      image[:name].should == "server_spec"
      delete "/images/#{image[:_id]}"
    end
  end

  describe "PUT on /images/:id" do
    it "should update an existing image metadata" do
      put "/images/#{@valid_id}", valid_update.to_json
      last_response.should be_ok

      response = JSON.parse(last_response.body, parse_opts)
      image    = response[:image]
      image.should be_instance_of Hash
      image[:_id].should be_instance_of Fixnum
      image[:architecture].should == "x86_64"
    end
  end

  describe "DELETE on /images/:id" do
    it "should delete an image metadata" do
      delete "/images/#{@valid_id}"
      last_response.should be_ok

      response = JSON.parse(last_response.body, parse_opts)
      image    = response[:image]
      image.should be_instance_of Hash
      image[:_id].should == @valid_id

      get "/images/#{@valid_id}"
      last_response.body.should =~ /No image found/

    end
  end

end
