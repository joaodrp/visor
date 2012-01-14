require 'spec_helper'

module Visor::Common
  describe Util do

    let(:meta) { {name: 'util_spec', architecture: 'i386', access: 'public'} }

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
  end
end
