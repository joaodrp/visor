require "spec_helper"

describe Visor::API::Server do
  include Visor::Common::Util

  let(:test_api) { Visor::API::Server }
  let(:err) { Proc.new { fail "API request failed" } }

  let(:accept_json) { {'Accept' => 'application/json'} }
  let(:accept_xml) { {'Accept' => 'application/xml'} }

  let(:parse_opts) { {symbolize_names: true} }
  let(:valid_post) { {name: 'server_spec', architecture: 'i386', access: 'public'} }
  let(:post_headers) { push_meta_into_headers(valid_post) }
  let(:api_options) { {debug: true, log_stdout: true, config: File.expand_path(File.join(File.dirname(__FILE__), '../../../', 'config/server.rb'))} }

  inserted = []

  before(:all) do
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
  # POST     /images
  #
  describe "POST /images/" do

    it "should post an image metadata and return it as response's body" do
      with_api(test_api, api_options) do
        post_request({:path => "/images/", :head => post_headers}, err) do |c|
          meta = parse_body(c)
          inserted << meta[:_id]
        end
      end
    end

    it "should return a JSON string if no accept header provided" do
      with_api(test_api, api_options) do
        post_request({:path => "/images/", :head => post_headers}, err) do |c|
          meta = parse_body(c)
          inserted << meta[:_id]
          c.response.should match /\{/
        end
      end
    end

    it "should return a JSON string if accepted" do
      with_api(test_api, api_options) do
        post_request({:path => "/images/", :head => post_headers.merge(accept_json)}, err) do |c|
          meta = parse_body(c)
          inserted << meta[:_id]
          c.response.should match /\{/
        end
      end
    end

    it "should return a XML document if accepted" do
      with_api(test_api, api_options) do
        post_request({:path => "/images/", :head => post_headers.merge(accept_xml)}, err) do |c|
          c.response.should match /\<?xml/
          inserted << c.response.scan(%r{<_id>([^<]+)</_id>}).flatten.first
        end
      end
    end

    it "should raise a 400 error if meta validation fails" do
      with_api(test_api, api_options) do
        headers = post_headers.merge('x-image-meta-store' => 'invalid one')
        post_request({:path => "/images/#{@id}", :head => headers, :body => 'something'}, err) do |c|
          assert_400 c
        end
      end
    end

    it "should raise a 400 error if no headers neither body provided" do
      with_api(test_api, api_options) do
        post_request({:path => "/images/#{@id}"}, err) do |c|
          assert_400 c
        end
      end
    end

    it "should raise a 400 error if location header and body are both provided" do
      with_api(test_api, api_options) do
        headers = post_headers.merge('x-image-meta-location' => 'file:///path/file.iso')
        post_request({:path => "/images/#{@id}", :head => headers, :body => 'something'}, err) do |c|
          assert_400 c
        end
      end
    end

    it "should raise a 400 error if store is HTTP" do
      with_api(test_api, api_options) do
        headers = post_headers.merge('x-image-meta-store' => 'http')
        post_request({:path => "/images/#{@id}", :head => headers, :body => 'something'}, err) do |c|
          assert_400 c
        end
      end
    end

  end
end
