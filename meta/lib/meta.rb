## Is this the best way to require another sub-system/gem in the same global project folder?
$:.unshift File.expand_path('../../../common/lib', __FILE__)
require 'common'
##
$:.unshift File.expand_path('../../lib', __FILE__)
require 'meta/version'
require 'meta/backends/base'
require 'meta/backends/mongo_db'
require 'meta/backends/mysql_db'
require 'meta/server'
require 'meta/client'
require 'meta/api'
require 'meta/cli'


