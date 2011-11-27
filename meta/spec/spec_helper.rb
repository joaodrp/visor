require 'rubygems'
require 'bundler/setup'

Bundler.require :default, :test

require File.expand_path '../../lib/registry', __FILE__
require File.dirname(__FILE__) + '/../lib/registry/server'

ENV['RACK_ENV'] = 'test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  def app
    Cbolt::Registry::Server
  end
end
