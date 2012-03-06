require "spec_helper"

describe Visor::Image::Store::HTTP do

  let(:klass) { Visor::Image::Store::FileSystem }

  let(:file_uri) { 'file:///path/to/my_image.iso' }
  let(:file_conf) { {:file => :configmock} }

  let(:duplicated) { Visor::Common::Exception::Duplicated }
  let(:unauthorized) { Visor::Common::Exception::Forbidden }
  let(:not_found) { Visor::Common::Exception::NotFound }

  describe "#initialize" do
    it "should initialize a filesystem store class" do
      klass.new(file_uri, file_conf).should be_a Visor::Image::Store::FileSystem
    end

    it "should parse uri and assign instance variables" do
      fs = klass.new(file_uri, file_conf)
      fs.uri.should be_a URI
      fs.fp.should == '/path/to/my_image.iso'
    end
  end

  describe "#file_exists?" do
    it "should raise NotFound exception if file doesnt exist" do
      fs = klass.new(file_uri, file_conf)
      proc { fs.file_exists? }.should raise_exception not_found
    end
  end
end
