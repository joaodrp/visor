require 'rubygems'
require 'bundler/setup'

Bundler.require :default, :test
#SimpleCov.start

require File.expand_path '../../lib/visor-auth', __FILE__
require File.expand_path '../../lib/auth/server', __FILE__

ENV['RACK_ENV'] = 'test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods

  def app
    Visor::Auth::Server
  end
end

set :environment, :test
set :run, false
set :raise_errors, false
set :show_exceptions, false
set :logging, false
