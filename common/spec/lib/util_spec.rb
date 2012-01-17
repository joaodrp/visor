require 'spec_helper'

module Visor::Common
  describe Util do

    let(:date) { Time.now }
    let(:meta) { {name: 'util_spec', architecture: 'i386', access: 'public', created_at: date} }

    let(:headers) { {'X_IMAGE_META_NAME'         => 'util_spec',
                     'X_IMAGE_META_ARCHITECTURE' => 'i386',
                     'X_IMAGE_META_ACCESS'       => 'public',
                     'X_IMAGE_META_CREATED_AT'   => date.to_s} }

    describe "#push_meta_into_headers" do
      it "should receive an hash and push it into another as HTTP headers" do
        headers = Visor::Common::Util.push_meta_into_headers(meta)
        headers.should be_a Hash
        i = 0
        headers.each do |k, v|
          orig_key = meta.keys[i]
          k.should == "x-image-meta-#{orig_key}"
          v.should == meta[orig_key.to_sym].to_s
          i+=1
        end
      end
    end

    describe "#push_meta_into_headers" do
      it "should receive an hash and pull HTTP headers to a new hash" do
        hash = Visor::Common::Util.pull_meta_from_headers(headers)
        hash.should be_a Hash
        hash.keys.should == meta.keys
      end

      it "should ignore non image meta headers" do
        hash = Visor::Common::Util.pull_meta_from_headers(headers.merge('X_EXTRA' => 'value'))
        hash.should_not include(:X_EXTRA)
      end
    end

  end
end
