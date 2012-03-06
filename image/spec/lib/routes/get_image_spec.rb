require "spec_helper"

describe Visor::Image::Server do
  include Visor::Common::Util

  let(:test_api) { Visor::Image::Server }
  let(:err) { Proc.new { fail "API request failed" } }

  let(:accept_json) { {'Accept' => 'application/json'} }
  let(:accept_xml) { {'Accept' => 'application/xml'} }

  let(:parse_opts) { {symbolize_names: true} }
  let(:valid_post) { {name: 'server_spec', architecture: 'i386', access: 'public'} }
  let(:api_options) { {config: File.expand_path(File.join(File.dirname(__FILE__), '../../../', 'config/server.rb'))} }

  inserted = []

  before(:each) do
    EM.synchrony do
      inserted << DB.post_image(valid_post)[:_id]
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
  # GET     /images/<id>
  #
  describe "GET /images/:id" do
    it "should return an image metadata in headers" do
      id = inserted.sample
      with_api(test_api, api_options) do
        get_request({:path => "/images/#{id}"}, err) do |c|
          assert_200 c
          pull_meta_from_headers(c.response_header).should_not be_empty
        end
      end
    end

    it "should return a JSON error if accepted" do
      with_api(test_api, api_options) do
        get_request({:path => "/images/fakeid", head: accept_json}, err) do |c|
          assert_404 c
          c.response.should match /\{/
        end
      end
    end

    it "should return a XML error if accepted" do
      with_api(test_api, api_options) do
        get_request({:path => "/images/fakeid", head: accept_xml}, err) do |c|
          assert_404 c
          c.response.should match /\<?xml/
        end
      end
    end

    it "should raise a HTTPNotFound 404 error if no images found" do
      with_api(test_api, api_options) do
        get_request({:path => "/images/fakeid"}, err) do |c|
          assert_404 c
          c.response.should match /fakeid/
        end
      end
    end

    it "should raise a HTTPInternalServer 500 error if no server error" do

    end

  end
end
