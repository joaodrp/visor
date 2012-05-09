## Is this the best way to require another sub-system/gem in the same global project folder?
require File.expand_path('../../../common/lib/visor-common', __FILE__)
##
$:.unshift File.expand_path('../../lib', __FILE__)
require 'auth/version'
require 'auth/backends/base'
require 'auth/backends/mongo_db'
require 'auth/backends/mysql_db'
require 'auth/server'
require 'auth/client'
require 'auth/cli'


