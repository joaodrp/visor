require "spec_helper"


describe Visor::Image::Store::S3 do

  let(:klass) { Visor::Image::Store::S3 }

  let(:s3_uri) { 's3://access_key:secret_key@s3.amazonaws.com/bucket/my_image.iso' }
  let(:s3_conf) { {:s3 => {:access_key => 'access_key',
                           :secret_key => 'secret_key',
                           :bucket     => 'bucket'}} }

  let(:not_found) { Visor::Common::Exception::NotFound }

  describe "#initialize" do
    it "should initialize http store class" do
      s3 = Visor::Image::Store::S3.new(s3_uri, s3_conf)
      s3.should be_a Visor::Image::Store::S3
    end

    it "should parse uri and assign it to the instance variables" do
      s3 = Visor::Image::Store::S3.new(s3_uri, s3_conf)
      s3.access_key.should == 'access_key'
      s3.secret_key.should == 'secret_key'
      s3.bucket.should == 'bucket'
      s3.file.should == 'my_image.iso'
    end

    it "should parse uri and assign it to the instance variables" do
      s3 = Visor::Image::Store::S3.new('', s3_conf)
      s3.access_key.should == 'access_key'
      s3.secret_key.should == 'secret_key'
      s3.bucket.should == 'bucket'
    end
  end

end
