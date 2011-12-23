## Is this the best way to require another sub-system/gem in the same global project folder?
$:.unshift File.expand_path('../../../common/lib', __FILE__)
require 'common'
##
$:.unshift File.expand_path('../lib', __FILE__)
require 'registry/version'
require 'registry/client'
require 'registry/api'
require 'registry/backends/base'
require 'registry/backends/mongo_db'
require 'registry/backends/mysql_db'

