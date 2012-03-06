require "spec_helper"

describe Visor::Image::Server do

  let(:test_api) { Visor::Image::Server }
  let(:err) { Proc.new { fail "API request failed" } }
  let(:valid_post) { {name: 'server_spec', architecture: 'i386', access: 'public'} }
  let(:api_options) { {config: File.expand_path(File.join(File.dirname(__FILE__), '../../../', 'config/server.rb'))} }

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
  # HEAD    /images/<id>
  #
  describe "HEAD /images/:id" do
    before :each do
      with_api(test_api, api_options) do
        head_request({:path => "/images/#{inserted.sample}"}, err) { |c| assert_200 c; @res = c }
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
      with_api(test_api, api_options) do
        head_request({:path => "/images/fake"}, err) { |c| assert_404_path_or_op c }
      end
    end
  end
end
