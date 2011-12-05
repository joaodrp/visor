require File.expand_path("../../spec_helper", __FILE__)

include Cbolt::Backends

module Cbolt::Backends
  describe Backend do

    before(:each) do
      @sample = {
          name: 'testsample',
          architecture: 'i386',
          access: 'public',
          format: 'iso'
      }

      @backend = Backend.new(host: 'fake', port: 'fake', db: 'fake')
    end

    describe "#validate_data_post" do
      it "should validate that no read-only field is setted" do
        Backend::READONLY.each do |field|
          l = lambda { @backend.validate_data_post @sample.merge(field => 'some value') }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end

      it "should validate that all mandatory fields are setted" do
        Backend::MANDATORY.each do |field|
          l = lambda { @backend.validate_data_post(@sample.select { |k, v| k != field }) }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end

      it "should validate the the fields values" do
        fields = [:architecture, :access, :store, :format, :type]
        fields.each do |field|
          inv = @sample.merge(field => 'invalid value!')
          l = lambda { @backend.validate_data_post inv }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end

      it "should set the blank keys value to nil" do
        l = lambda { @backend.validate_data_post @sample }
        @sample[:store].should == nil
        @sample[:name].should == 'testsample'
      end
    end

    describe "#validate_data_put" do
      it "should validate that no read-only field is setted" do
        Backend::READONLY.each do |field|
          l = lambda { @backend.validate_data_put @sample.merge(field => 'some value') }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end

      it "should validate the the fields values" do
        fields = [:architecture, :access, :store, :format, :type]
        fields.each do |field|
          inv = @sample.merge(field => 'invalid value!')
          l = lambda { @backend.validate_data_post inv }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end
    end
  end
end
