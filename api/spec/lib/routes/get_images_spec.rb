require "spec_helper"

describe Visor::API::Server do

  let(:test_api) { Visor::API::Server }
  let(:err) { Proc.new { fail "API request failed" } }
  let(:accept) { {'Accept' => 'application/json'} }
  let(:parse_opts) { {symbolize_names: true} }
  let(:valid_post) { {name: 'server_spec', architecture: 'i386', access: 'public'} }
  let(:api_options) { {config: File.expand_path(File.join(File.dirname(__FILE__), '../../../', 'lib/api/config/server.rb'))} }

  inserted = []

  before(:all) do
    EM.synchrony do
      inserted << DB.post_image(valid_post)[:_id]
      inserted << DB.post_image(valid_post.merge(architecture: 'x86_64'))[:_id]
      EM.stop
    end
  end

  after(:all) do
    EM.synchrony do
      inserted.each { |id| DB.delete_image(id) }
      EM.stop
    end
  end

  #
  # GET     /images
  #
  describe "GET /images" do
    before :each do
      with_api(test_api, api_options) do
        get_request({:path => '/images', head: accept}, err) { |c| assert_200 c; @res = c }
      end
    end

    it "should return a JSON string" do
      @res.response.should be_a String
    end

    it "should return all images meta hashes inside an array" do
      res = parse_body @res
      res.should be_a Array
      res.first.should be_a Hash
    end

    it "should accept filter query parameters" do
      with_api(test_api, api_options) do
        get_request({path: '/images', head: accept, query: {architecture: 'i386'}}, err) do |c|
          body = parse_body c
          body.should be_a Array
          body.each { |meta| meta[:architecture].should == 'i386' }
        end
      end
    end

    it "should accept sorting query parameters" do
      with_api(test_api, api_options) do
        get_request({path: '/images', head: accept, query: {sort: 'architecture', dir: 'desc'}}, err) do |c|
          body = parse_body c
          body.should be_a Array
          body.first[:architecture].should == 'x86_64'
          body.last[:architecture].should == 'i386'
        end
      end
    end

    it "should raise a HTTPNotFound 404 error if no images found" do

    end
  end
end
