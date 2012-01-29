require "spec_helper"

describe Visor::API::Server do

  let(:test_api) { Visor::API::Server }
  let(:err) { Proc.new { fail "API request failed" } }
  let(:accept) { {'Accept' => 'application/json'} }
  let(:api_options) { {config: File.expand_path(File.join(File.dirname(__FILE__), '../..', 'config/server.rb'))} }

  #
  # Assert allowed methods by path
  #
  describe "On /images" do
    it "should only accept GET and POST methods" do
      with_api(test_api, api_options) do
        put_request({path: '/images', head: accept}, err) do |c|
          assert_405(c, %w(GET POST))
        end
      end
    end
  end

  describe "On /images/:id" do
    it "should only accept GET, HED, PUT and DELETE methods" do
      with_api(test_api, api_options) do
        post_request({path: '/images/fake', head: accept}, err) do |c|
          assert_405(c, %w(DELETE GET HEAD PUT))
        end
      end
    end
  end

  #
  # Not Found
  #
  describe "Operation on a not implemented path" do
    it "should raise a 404 error for a GET request" do
      with_api(test_api, api_options) do
        get_request({:path => '/fake'}, err) { |c| assert_404_path_or_op c }
      end
    end

    it "should raise a 404 error for a POST request" do
      with_api(test_api, api_options) do
        post_request({:path => '/fake'}, err) { |c| assert_404_path_or_op c }
      end
    end

    it "should raise a 404 error for a PUT request" do
      with_api(test_api, api_options) do
        put_request({:path => '/fake'}, err) { |c| assert_404_path_or_op c }
      end
    end

    it "should raise a 404 error for a POST request" do
      with_api(test_api, api_options) do
        delete_request({:path => '/fake'}, err) { |c| assert_404_path_or_op c }
      end
    end
  end
end

