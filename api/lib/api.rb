## Is this the best way to require another sub-system/gem in the same global project folder?
require File.expand_path('../../../common/lib/common', __FILE__)
##
$:.unshift File.expand_path('../../lib', __FILE__)
require 'api/version'
require 'api/meta'
#require 'api/server'
#require 'api/client'


