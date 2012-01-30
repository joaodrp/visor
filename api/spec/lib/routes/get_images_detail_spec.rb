require "spec_helper"

describe Visor::API::Server do

  let(:test_api) { Visor::API::Server }
  let(:err) { Proc.new { fail "API request failed" } }
  let(:accept_json) { {'Accept' => 'application/json'} }
  let(:accept_xml) { {'Accept' => 'application/xml'} }
  let(:parse_opts) { {symbolize_names: true} }
  let(:valid_post) { {name: 'server_spec', architecture: 'i386', access: 'public'} }
  let(:api_options) { {config: File.expand_path(File.join(File.dirname(__FILE__), '../../../', 'config/server.rb'))} }

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
  # GET     /images/detail
  #
  describe "GET /images/detail" do

    it "should return a JSON string if no accept header provided" do
      with_api(test_api, api_options) do
        get_request({:path => '/images'}, err) do |c|
          assert_200 c
          c.response.should be_a String
          c.response.should match /\{/
        end
      end
    end

    it "should return all images meta hashes inside a JSON array" do
      with_api(test_api, api_options) do
        get_request({:path => '/images'}, err) do |c|
          res = parse_body c
          res.should be_a Array
          res.first.should be_a Hash
        end
      end
    end

    it "should return a JSON string if accepted" do
      with_api(test_api, api_options) do
        get_request({:path => '/images', head: accept_json}, err) do |c|
          assert_200 c
          c.response.should be_a String
          c.response.should match /\{/
        end
      end
    end

    it "should return a XML document if accepted" do
      with_api(test_api, api_options) do
        get_request({:path => '/images', head: accept_xml}, err) do |c|
          assert_200 c
          c.response.should be_a String
          c.response.should match /\<?xml/
        end
      end
    end

    it "should accept filter query parameters" do
      with_api(test_api, api_options) do
        get_request({path: '/images/detail', head: accept_json, query: {architecture: 'i386'}}, err) do |c|
          body = parse_body c
          body.should be_a Array
          body.each { |meta| meta[:architecture].should == 'i386' }
        end
      end
    end

    it "should accept sorting query parameters" do
      with_api(test_api, api_options) do
        get_request({path: '/images/detail', head: accept_json, query: {sort: 'architecture', dir: 'desc'}}, err) do |c|
          body = parse_body c
          body.should be_a Array
          body.first[:architecture].should == 'x86_64'
          body.last[:architecture].should == 'i386'
        end
      end
    end

    it "should raise a HTTPNotFound 404 error if no images found" do

    end

    it "should raise a HTTPInternalServer 500 error if no server error" do

    end
  end
end
