include Cbolt::Backends

describe Cbolt::Registry::Server do

  describe "GET on /" do
    it "should return an array of images" do
      get '/'
      last_response.should be_ok
      images = JSON.parse(last_response.body)
      images.should be_instance_of Array
    end

    it "should return only brief information fields" do
      get '/'
      images = JSON.parse(last_response.body, :symbolize_names => true)
      images.each do |img|
        img.keys.sort.should == Backend::BRIEF.sort
      end
    end
  end

  describe "GET on /images" do
    it "should return an array of images" do
      get '/images'
      last_response.should be_ok
      images = JSON.parse(last_response.body)
      images.should be_instance_of Array
    end

    it "should return only detail information fields" do
      get '/images'
      images = JSON.parse(last_response.body, :symbolize_names => true)
      images.each do |img|
        (img.keys & Backend::DETAIL_EXC).should be_empty
      end
    end
  end

  describe "GET on /images/:id" do
    it "should return a hash with the given image meta" do
      get '/images/10'
      images = JSON.parse(last_response.body, :symbolize_names => true)
      images.should be_instance_of Hash
    end

    it "should return only detail information fields" do
      get '/images/10'
      images = JSON.parse(last_response.body, :symbolize_names => true)
      (images.keys & Backend::DETAIL_EXC).should be_empty
    end

  end

end
