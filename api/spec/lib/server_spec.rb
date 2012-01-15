require "spec_helper"

require File.expand_path '../../../lib/api/server', __FILE__

describe Visor::API::Server do

  let(:test_api) { Visor::API::Server }
  let(:err) { Proc.new { fail "API request failed" } }
  let(:accept) { {'Accept' => 'application/json'} }
  let(:parse_opts) { {symbolize_names: true} }

  let(:not_found) { Visor::Common::Exception::NotFound }
  let(:invalid) { Visor::Common::Exception::Invalid }

  let(:valid_post) { {name: 'server_spec', architecture: 'i386', access: 'public'} }
  let(:invalid_post) { {name: 'server_spec', architecture: 'i386', access: 'invalid'} }

  let(:valid_update) { {architecture: 'x86_64'} }
  let(:invalid_update) { {architecture: 'invalid'} }

  #
  # Helper methods
  #
  def assert_200(c)
    c.response_header.status.should == 200
  end

  def assert_404(c)
    c.response_header.status.should == 404
    c.response.should =~ /404/
    c.response.should =~ /No image found with id/
  end

  def assert_404_path_or_op(c)
    c.response_header.status.should == 404
    unless c.response.empty?
      c.response.should =~ /404/
      c.response.should =~ /Invalid operation or path/
    end
  end

  def assert_405(c, allow)
    c.response_header.status.should == 405
    c.response_header['ALLOW'].split(/, /).should == allow
  end

  def parse_body(c)
    assert_200 c
    body = JSON.parse(c.response, parse_opts)
    body[:image] || body[:images] || body[:message]
  end

  #
  # Assert allowed methods by path
  #
  describe "On /images" do
    it "should only accept GET and POST methods" do ############
      with_api(test_api) do
        put_request({path: '/images', head: accept}, err) { |c| assert_405(c, %w(GET)) }
      end
    end
  end

  describe "On /images/:id" do
    it "should only accept GET, HED, PUT and DELETE methods" do ########
      with_api(test_api) do
        post_request({path: '/images/fake', head: accept}, err) { |c| assert_405(c, %w(GET HEAD)) }
      end
    end
  end

  #
  # HEAD    /images/<id>
  #
  describe "HEAD /images/:id" do
    before :each do
      id = "763eea76-4b0d-4f9b-88cf-aa618674165f" ###############################
      with_api(test_api) do
        head_request({:path => "/images/#{id}", head: accept}, err) { |c| assert_200 c; @res = c }
      end
    end

    it "should return an empty body hash" do
      @res.response.should be_empty
    end

    it "should return image metadata as HTTP headers" do
      created_at = @res.response_header['X_IMAGE_META_CREATED_AT']
      Date.parse(created_at).should be_a Date
    end

    it "should raise a HTTPNotFound 404 error if image not found" do
      with_api(test_api) do
        head_request({:path => "/images/fake", head: accept}, err) { |c| assert_404_path_or_op c }
      end
    end
  end

  #
  # GET     /images
  #
  describe "GET /images" do
    before :each do
      with_api(test_api) do
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
      with_api(test_api) do
        get_request({path: '/images', head: accept, query: {architecture: 'i386'}}, err) do |c|
          body = parse_body c
          body.should be_a Array
          body.each { |meta| meta[:architecture].should == 'i386' }
        end
      end
    end

    it "should accept sorting query parameters" do
      with_api(test_api) do
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

  #
  # GET     /images/detail
  #
  describe "GET /images/detail" do
    before :each do
      with_api(test_api) do
        get_request({path: '/images/detail', head: accept}, err) { |c| assert_200 c; @res = c }
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
      with_api(test_api) do
        get_request({path: '/images/detail', head: accept, query: {architecture: 'i386'}}, err) do |c|
          body = parse_body c
          body.should be_a Array
          body.each { |meta| meta[:architecture].should == 'i386' }
        end
      end
    end

    it "should accept sorting query parameters" do
      with_api(test_api) do
        get_request({path: '/images/detail', head: accept, query: {sort: 'architecture', dir: 'desc'}}, err) do |c|
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

  #
  # GET     /images/<id>
  #
  describe "GET /images/:id" do
    before :each do
      id = "763eea76-4b0d-4f9b-88cf-aa618674165f" ###############################
      with_api(test_api) do
        get_request({:path => "/images/#{id}", head: accept}, err) { |c| assert_200 c; @res = c }
      end
    end

    it "should return image metadata as HTTP headers" do
      created_at = @res.response_header['X_IMAGE_META_CREATED_AT']
      Date.parse(created_at).should be_a Date
    end

    it "should return image file on response's body" do
      @res.response_header['CONTENT_TYPE'].should == 'application/octet-stream'
      @res.response_header['X_STREAM'].should == 'Goliath'
      @res.response.should_not be_empty
    end

    it "should raise a HTTPNotFound 404 error if image not found" do
      with_api(test_api) do
        get_request({:path => "/images/fake", head: accept}, err) { |c| assert_404 c }
      end
    end
  end

  #
  # Not Found
  #
  describe "Operation on a not implemented path" do
    it "should raise a 404 error for a GET request" do
      with_api(test_api) do
        get_request({:path => '/fake'}, err) { |c| assert_404_path_or_op c }
      end
    end

    it "should raise a 404 error for a POST request" do
      with_api(test_api) do
        post_request({:path => '/fake'}, err) { |c| assert_404_path_or_op c }
      end
    end

    it "should raise a 404 error for a PUT request" do
      with_api(test_api) do
        put_request({:path => '/fake'}, err) { |c| assert_404_path_or_op c }
      end
    end

    it "should raise a 404 error for a POST request" do
      with_api(test_api) do
        delete_request({:path => '/fake'}, err) { |c| assert_404_path_or_op c }
      end
    end
  end

end

