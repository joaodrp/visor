require "spec_helper"

include Visor::Meta::Backends

module Visor::Meta::Backends
  describe Base do

    before(:each) do
      @sample = {
          name: 'testsample',
          architecture: 'i386',
          access: 'public',
          format: 'iso'
      }

      @base = Base.new(host: 'fake', port: 'fake', db: 'fake')
    end

    describe "#initialize" do
      it "should create an Base instance" do
        base = Base.new(host: 'fake')
        base.host.should == 'fake'
      end
    end

    describe "#validate_data_post" do
      it "should validate that no read-only field is setted" do
        Base::READONLY.each do |field|
          l = lambda { @base.validate_data_post @sample.merge(field => 'some value') }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end

      it "should validate that all mandatory fields are setted" do
        Base::MANDATORY.each do |field|
          l = lambda { @base.validate_data_post(@sample.select { |k, v| k != field }) }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end

      it "should validate fields values" do
        fields = [:architecture, :access, :store, :format, :type]
        fields.each do |field|
          inv = @sample.merge(field => 'invalid value!')
          l = lambda { @base.validate_data_post inv }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end
    end

    describe "#validate_data_put" do
      it "should validate that no read-only field is setted" do
        Base::READONLY.each do |field|
          l = lambda { @base.validate_data_put @sample.merge(field => 'some value') }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end

      it "should validate the the fields values" do
        fields = [:architecture, :access, :store, :format, :type]
        fields.each do |field|
          inv = @sample.merge(field => 'invalid value!')
          l = lambda { @base.validate_data_post inv }
          l.should raise_error(ArgumentError, /#{field}/)
        end
      end
    end

    describe "#validate_query_filters" do
      it "should validate if query only contains valid filter keys" do
        @base.validate_query_filters(Base::FILTERS.sample => 'value')
      end

      it "should raise if query has some invalid filter key" do
        l = lambda { @base.validate_query_filters(invalid_filter: 'value') }
        l.should raise_error(ArgumentError, /invalid_filter/)
      end
    end

    describe "#set_protected_post" do
      before(:each) do
        @meta = {name: 'testsample',
                 architecture: 'i386',
                 format: 'iso',
                 owner: 'someone',
                 size: 1}
        @base.set_protected_post @meta
      end

      it "should set the _id to a SecureRandom UUID" do
        @meta[:_id].should be_a String
        @meta[:_id].size.should == 36
      end

      it "should set the access to public if not provided" do
        @meta[:access].should == 'public'
      end

      it "should set the created_at" do
        @meta[:created_at].should be_a Time
      end

      it "should set the uri" do
        @meta[:uri].should be_a String
        @meta[:uri] =~ /#{@meta[:_id]}/
      end

      it "should set the status to locked" do
        @meta[:status].should == 'locked'
      end

      it "should set the owner if provided" do
        @meta[:owner].should == 'someone'
      end

      it "should set the size if provided" do
        @meta[:size].should == 1
      end
    end

    describe "#set_protected_put" do
      it "should set the updated_at" do
        meta = {name: 'new name',
                architecture: 'i386'}
        @base.set_protected_put meta
        meta[:updated_at].should be_a Time
      end
    end
    
    describe "#build_uri" do
      it "should build a new URI" do
        uri = @base.build_uri('some_id')
        uri.should be_a String
        uri =~ %r{^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$/}ix
      end
    end

    describe "#serialize_others" do
      it "should encapsulate extra fields on the others field" do
        sample = {name: 'example', access: 'public', extra_key: 'value', another: 'value'}
        new = @base.serialize_others(sample)
        new[:others].should == "{\"extra_key\":\"value\",\"another\":\"value\"}"
      end
    end

    describe "#serialize_others" do
      it "should encapsulate extra fields on the others field as JSON" do
        sample = {name: 'example', access: 'public', extra_key: 'value', another: 'value'}
        @base.serialize_others(sample)
        sample[:others].should == "{\"extra_key\":\"value\",\"another\":\"value\"}"
      end

      it "should do nothing if there are no extra fields" do
        sample = {name: 'example', access: 'public'}
        copy = sample.dup
        @base.serialize_others(sample)
        sample.should == copy
      end
    end

    describe "#deserialize_others" do
      it "should decapsulate extra fields from the others field" do
        sample = {name: 'example', access: 'public', extra_key: 'value', another: 'value'}
        new = @base.deserialize_others(@base.serialize_others(sample))
        new.should == sample
      end

      it "should do nothing if there are no extra fields" do
        sample = {name: 'example', access: 'public'}
        copy = sample.dup
        @base.deserialize_others(sample)
        sample.should == copy
      end
    end
    
    describe "#string_time_or_hash?" do
      it "should return true if parameter is a String a Time or a Hash" do
         @base.string_time_or_hash?("").should be_true
         @base.string_time_or_hash?(Time.now).should be_true
         @base.string_time_or_hash?({}).should be_true
      end

      it "should return false if parameter is of other class" do
        @base.string_time_or_hash?(1).should be_false
      end
    end
    
    describe "#to_sql_where" do
      it "should return a AND joined valid SQL WHERE string from a hash" do
        str = @base.to_sql_where(a: 1, b: 'something')
        str.should == "a=1 AND b='something'"
      end
    end

    describe "#to_sql_update" do
      it "should return a comma joined valid SQL UPDATE string from a hash" do
        str = @base.to_sql_update(a: 1, b: 'something')
        str.should == "a=1, b='something'"
      end
    end

    describe "#to_sql_insert" do
      it "should return a VALUES joined valid SQL INSERT array from a hash" do
        arr = @base.to_sql_insert(a: 1, b: 'something')
        arr.should == ["(a, b)", "(1, 'something')"]
      end
    end
  end
end
