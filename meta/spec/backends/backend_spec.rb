require "spec_helper"
require 'registry/backends/mongo'

module Registry::Backends
  describe Backend do


    before(:each) do
      @conn = Registry::Backends::MongoDB.new :db => 'mongo-test'
      @sample = {
          name: 'testsample',
          architecture: 'i386',
          access: 'public',
          format: 'iso'
      }
      @sample2 = {
          name: 'abc',
          architecture: 'i386',
          access: 'public',
          type: 'amazon'
      }
      @sample3 = {
          name: 'xyz',
          architecture: 'x86_64',
          access: 'public',
          type: 'kernel'
      }
      @conn.connection(:images).insert(@sample)
      @conn.connection(:images).insert(@sample2)
      @conn.connection(:counters).insert(:fake => 'none')
    end

    after(:each) do
      @conn.connection(:images).remove
    end

    describe "#set_protected" do
      it "should set the protected fields for a post operation" do
        @sample.merge!(:_id => 0, :status => '', :updated_at => Time.now)
        old_updated_at = @sample[:updated_at]

        @conn.set_protected(@sample, :post)
        @sample[:uri].should == "http://#{@conn.host}:#{@conn.port}/images/#{0}"
        @sample[:status].should == 'locked'
        @sample[:updated_at].should be > old_updated_at
      end

      it "should set optional protected fields for a post operation" do
        @conn.set_protected(@sample, :post, :owner => 'someowner', :size => 'somesize')
        @sample[:owner].should == 'someowner'
        @sample[:size].should == 'somesize'
      end

      it "should set the protected fields for a put operation" do
        @sample.merge!(:updated_at => Time.now)
        old_updated_at = @sample[:updated_at]

        @conn.set_protected(@sample, :put)
        @sample[:updated_at].should be > old_updated_at
      end

      it "should set the protected fields for a get operation" do
        @sample.merge!(:accessed_at => Time.now)
        @sample.merge!(:access_count => 0)
        old_accessed_at = @sample[:accessed_at]

        @conn.set_protected(@sample, :get)
        @sample[:accessed_at].should be > old_accessed_at
        @sample[:access_count].should == 1
      end

      it "should raise an exception if operation is not valid" do
        l = lambda { @conn.set_protected(@sample, :some_invalid_op) }
        l.should raise_error(RuntimeError)
      end
    end

    describe "#validate_data" do
      context "from a post operation" do
        it "should validate that no read-only field is setted" do
          Registry::READONLY.each do |field|
            ro = @sample3.merge(field.to_sym => 'this is a r-o field!!')
            l = lambda { @conn.validate_data(ro, :post) }
            l.should raise_error(Registry::Invalid, /#{field}/)
          end
        end

        it "should validate that all mandatory fields are setted" do
          Registry::MANDATORY.each do |field|
            mand = @sample3.select { |k, v| k != field.to_sym }
            l = lambda { @conn.validate_data(mand, :post) }
            l.should raise_error(Registry::Invalid, /#{field}/)
          end
        end

        it "should validate the architecture field value" do
          fields = [:architecture, :access, :store, :format, :type]
          fields.each do |field|
            inv = @sample3.merge(field => 'invalid value!')
            l = lambda { @conn.validate_data(inv, :post) }
            l.should raise_error(Registry::Invalid, /#{field}/)
          end
        end

        it "should validate the existence of a kernel image" do
          # no image found with the given id
          invalid_kernel_image_id = 0
          inv = @sample3.merge(:kernel => invalid_kernel_image_id)
          l = lambda { @conn.validate_data(inv, :post) }
          l.should raise_error(Registry::NotFound, /0/)
          # the image found is not a kernel type image
          not_kernel = @conn.connection(:images).find(:type => 'amazon').to_a.first['_id']
          inv = @sample3.merge(:kernel => not_kernel)
          l = lambda { @conn.validate_data(inv, :post) }
          l.should raise_error(Registry::Invalid, /#{not_kernel}/)
        end

        it "should validate the existence of a ramdisk image" do
          # no image found with the given id
          invalid_ramdisk_image_id = 0
          inv = @sample3.merge(:ramdisk => invalid_ramdisk_image_id)
          l = lambda { @conn.validate_data(inv, :post) }
          l.should raise_error(Registry::NotFound, /0/)
          # the image found is not a ramdisk type image
          not_ramdisk = @conn.connection(:images).find(:type => 'amazon').to_a.first['_id']
          inv = @sample3.merge(:ramdisk => not_ramdisk)
          l = lambda { @conn.validate_data(inv, :post) }
          l.should raise_error(Registry::Invalid, /#{not_ramdisk}/)
        end
      end

      context "from a put operation" do
        it "should validate that no read-only field is setted" do
          Registry::READONLY.each do |field|
            ro = @sample3.merge(field.to_sym => 'this is a r-o field!!')
            l = lambda { @conn.validate_data(ro, :put) }
            l.should raise_error(Registry::Invalid, /#{field}/)
          end
        end

        it "should validate the existence of a kernel image" do
          # no image found with the given id
          invalid_kernel_image_id = 0
          inv = @sample3.merge(:kernel => invalid_kernel_image_id)
          l = lambda { @conn.validate_data(inv, :post) }
          l.should raise_error(Registry::NotFound, /0/)
          # the image found is not a kernel type image
          not_kernel = @conn.connection(:images).find(:type => 'amazon').to_a.first['_id']
          inv = @sample3.merge(:kernel => not_kernel)
          l = lambda { @conn.validate_data(inv, :post) }
          l.should raise_error(Registry::Invalid, /#{not_kernel}/)
        end

        it "should validate the existence of a ramdisk image" do
          # no image found with the given id
          invalid_ramdisk_image_id = 0
          inv = @sample3.merge(:ramdisk => invalid_ramdisk_image_id)
          l = lambda { @conn.validate_data(inv, :post) }
          l.should raise_error(Registry::NotFound, /0/)
          # the image found is not a ramdisk type image
          not_ramdisk = @conn.connection(:images).find(:type => 'amazon').to_a.first['_id']
          inv = @sample3.merge(:ramdisk => not_ramdisk)
          l = lambda { @conn.validate_data(inv, :post) }
          l.should raise_error(Registry::Invalid, /#{not_ramdisk}/)
        end
      end
    end
  end
end
