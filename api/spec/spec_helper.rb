require 'rubygems'
require 'bundler/setup'

Bundler.require :default, :test
SimpleCov.start

require File.expand_path '../../lib/api', __FILE__

require 'goliath/test_helper'

Goliath.env = :test

RSpec.configure do |c|
  c.include Goliath::TestHelper, :example_group => {
      :file_path => /spec\/lib/
  }
end
