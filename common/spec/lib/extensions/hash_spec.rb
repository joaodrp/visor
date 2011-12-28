require 'spec_helper'

module Visor::Common::Extensions
  describe Hash do

    let(:h_symbols) { {a: 1, b: 2, c: {d: 4, e: 5}} }
    let(:h_strings) { {'a' => 1, 'b' => 2, 'c' => {'d' => 4, 'e' => 5}} }

    let(:simple_hash) { {a: 1, b: 2, c: 3, d: 4, e: 5} }
    let(:valid_keys) { [:a, :b, :c, :d, :e] }
    let(:inclusion_keys) { [:a, :b, :c, :d, :e] }
    let(:exclusion_keys) { [:f, :g] }

    describe "#stringify_keys" do
      it "should return a new hash" do
        h_symbols.stringify_keys.should be_a Hash
      end

      it "should return the hash with all keys stringified" do
        h_symbols.stringify_keys.keys.each { |k| k.should be_a String }
      end

      it "should succed at any hash depth" do
        new = h_symbols.stringify_keys
        new['c'].keys.each { |k| k.should be_a String }
      end
    end

    describe "#stringify_keys!" do
      it "should replace the hash with all keys stringified" do
        h_symbols.stringify_keys!
        h_symbols.keys.each { |k| k.should be_a String }
      end

      it "should succed at any hash depth" do
        h_symbols.stringify_keys!
        h_symbols['c'].keys.each { |k| k.should be_a String }
      end
    end

    describe "#symbolize_keys" do
      it "should return a new hash" do
        h_strings.symbolize_keys.should be_a Hash
      end

      it "should return the hash with all keys symbolized" do
        h_strings.symbolize_keys.keys.each { |k| k.should be_a Symbol }
      end

      it "should succed at any hash depth" do
        new = h_strings.symbolize_keys
        new[:c].keys.each { |k| k.should be_a Symbol }
      end
    end

    describe "#symbolize_keys!" do
      it "should replace the hash with all keys symbolized" do
        h_strings.symbolize_keys!
        h_strings.keys.each { |k| k.should be_a Symbol }
      end

      it "should succed at any hash depth" do
        h_strings.symbolize_keys!
        h_strings[:c].keys.each { |k| k.should be_a Symbol }
      end
    end

    describe "#assert_valid_keys" do
      it "should validate that all keys are valid" do
        l = lambda { simple_hash.assert_valid_keys(simple_hash.keys) }
        l.should_not raise_exception
      end
      
      it "should raise if any key is not valid" do
        l = lambda { simple_hash.assert_valid_keys([:x, :y, :z]) }
        l.should raise_exception ArgumentError
      end
    end

    describe "#assert_inclusion_keys" do
      it "should validate that all mandatory keys are present" do
        l = lambda { simple_hash.assert_inclusion_keys(inclusion_keys) }
        l.should_not raise_exception
      end

      it "should raise if any mandatory keys are not present" do
        l = lambda { simple_hash.assert_inclusion_keys(inclusion_keys << :new_one) }
        l.should raise_exception ArgumentError
      end
    end

    describe "#assert_exclusion_keys" do
      it "should validate that all exclusion keys are not present" do
        l = lambda { simple_hash.assert_exclusion_keys(exclusion_keys) }
        l.should_not raise_exception
      end

      it "should raise if any exclusion keys are present" do
        l = lambda { simple_hash.assert_exclusion_keys(exclusion_keys << :a) }
        l.should raise_exception ArgumentError
      end
    end

    describe "#assert_valid_values_for" do
      it "should validate that a given key has a given possible value" do
        l = lambda { simple_hash.assert_valid_values_for(:a, [1, 2, 3]) }
        l.should_not raise_exception
      end

      it "should raise if any exclusion keys are present" do
        l = lambda { simple_hash.assert_valid_values_for(:a, [4, 5, 6]) }
        l.should raise_exception ArgumentError
      end
    end

    describe "#set_blank_keys_value_to" do
      it "should fill blank/non existing keys to a given value" do
        simple_hash.set_blank_keys_value_to([:x, :y, :z], [], 1)
        [:x, :y, :z].each { |el| simple_hash[el].should == 1 }
      end

      it "should ignore some fields if asked to" do
        simple_hash.set_blank_keys_value_to([:x, :y, :z], [:z], 1)
        [:x, :y].each { |el| simple_hash[el].should == 1 }
        simple_hash[:z].should be_nil
      end
    end

    describe "#to_openstruct" do
      it "should return an OpenStruct object from a hash one" do
        os = simple_hash.to_openstruct
        os.should be_a OpenStruct
        os.a.should == simple_hash[:a]
      end
    end

  end
end
