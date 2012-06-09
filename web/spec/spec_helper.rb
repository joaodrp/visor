require 'rubygems'
require 'bundler/setup'

Bundler.require :default, :test
#SimpleCov.start

require File.expand_path '../../lib/visor-web', __FILE__
