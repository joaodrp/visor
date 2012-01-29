require "spec_helper"

describe Visor::API::Store do
  include Visor::API::Store

  let(:s3_uri) { 's3://access_key:secret_key@s3.amazonaws.com/bucket/my_image.iso' }
  let(:file_uri) { 'file:///path/to/my_image.iso' }
  let(:http_uri) { 'http://www.domain.com/path-to-image-file' }

  let(:s3_conf) { {:s3 => :configmock} }
  let(:file_conf) { {:file => :configmock} }
  let(:http_conf) { {:http => :configmock} }

  let(:unsupported_store) { Visor::Common::Exception::UnsupportedStore }

  describe "#get_backend" do
    it "should return the correct store backend class from an uri" do
      get_backend(s3_uri, s3_conf).should be_a Visor::API::Store::S3
      get_backend(file_uri, file_conf).should be_a Visor::API::Store::FileSystem
      get_backend(http_uri, http_conf).should be_a Visor::API::Store::HTTP
    end

    it "should return the correct store backend class from its name" do
      get_backend('file', file_conf).should be_a Visor::API::Store::FileSystem
      get_backend('http', http_conf).should be_a Visor::API::Store::HTTP
    end

    it "should raise an UnsupportedStore exception if bad uri" do
      proc { get_backend(s3_uri.sub('s3', 's2'), s3_conf) }.should raise_exception unsupported_store
    end

    it "should raise an UnsupportedStore exception if bad name" do
      proc { get_backend('filee', s3_conf) }.should raise_exception unsupported_store
    end
  end
end
