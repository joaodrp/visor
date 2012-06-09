require 'visor-common'

$:.unshift File.expand_path('../../lib', __FILE__)
require 'meta/version'
require 'meta/backends/base'
require 'meta/backends/mongo_db'
require 'meta/backends/mysql_db'
require 'meta/server'
require 'meta/client'
require 'meta/cli'


