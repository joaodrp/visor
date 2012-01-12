require "spec_helper"

describe Visor::API::Server do

  describe "Operation on a not implemented path" do

    def validate_error cb
      cb.response_header.status.should == 404
      cb.response.should =~ /404/
      cb.response.should =~ /Invalid operation or path/
    end

    it "should raise a 404 error for a GET request" do
      with_api(Visor::API::Server) do
        get_request({:path => '/fake'}, err) do |cb|
          validate_error cb
        end
      end
    end

    it "should raise a 404 error for a POST request" do
      with_api(Visor::API::Server) do
        post_request({:path => '/fake'}, err) do |cb|
          validate_error cb
        end
      end
    end

    it "should raise a 404 error for a PUT request" do
      with_api(Visor::API::Server) do
        put_request({:path => '/fake'}, err) do |cb|
          validate_error cb
        end
      end
    end

    it "should raise a 404 error for a POST request" do
      with_api(Visor::API::Server) do
        delete_request({:path => '/fake'}, err) do |cb|
          cb.response_header.status.should == 404
          cb.response.should =~ /Invalid operation or path/
        end
      end
    end
  end

end

