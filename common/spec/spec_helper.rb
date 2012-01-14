require 'rubygems'
require 'bundler/setup'

Bundler.require :default, :test
#SimpleCov.start

require File.expand_path '../../lib/common', __FILE__
