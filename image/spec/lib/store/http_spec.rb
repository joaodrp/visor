require "spec_helper"

describe Visor::Image::Store::HTTP do

  let(:klass) { Visor::Image::Store::HTTP }

  let(:http_uri) { 'http://www.ubuntu.com/start-download?distro=server&bits=64&release=latest' }
  let(:http_conf) { {:http => :configmock} }

  let(:unsupported_store) { Visor::Common::Exception::UnsupportedStore }
  let(:not_found) { Visor::Common::Exception::NotFound }

  before(:all) do
    @valid_http = Visor::Image::Store::HTTP.new(http_uri)
    @invalid_http = Visor::Image::Store::HTTP.new('http://a1g2.fake.com/')
  end

  describe "#initialize" do
    it "should initialize http store class" do
      @valid_http.should be_a Visor::Image::Store::HTTP
    end
  end

  describe "#file_exists?" do
    it "should return an array with exist flag, size and checksum" do
      EM.synchrony do
        @valid_http.file_exists?.should be_a Array
        EM.stop
      end
    end

    #it "should assert that a valid http file exists" do
    #  EM.synchrony do
    #    @valid_http.file_exists?[0].should be true
    #    EM.stop
    #  end
    #end
    #
    #it "should also return the size and checksum of the file" do
    #  EM.synchrony do
    #    result = @valid_http.file_exists?
    #    result[1].should be_a Fixnum
    #    result[2].should be_a String
    #    EM.stop
    #  end
    #end

    #it "should raise NotFound exception if file doesnt exist" do
    #  EM.synchrony do
    #    proc { @invalid_http.file_exists? }.should raise_exception not_found
    #    EM.stop
    #  end
    #end
  end

end
