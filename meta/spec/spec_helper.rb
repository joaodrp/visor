require 'rubygems'
require 'bundler/setup'

Bundler.require :default, :test

require File.expand_path '../../lib/registry', __FILE__
require File.expand_path '../../lib/registry/server', __FILE__

ENV['RACK_ENV'] = 'test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  def app
    Cbolt::Registry::Server
  end
end

# set test environment
set :environment, :test
#set :run, false
#set :raise_errors, true
#set :logging, false
