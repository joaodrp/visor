require 'visor-common'

$:.unshift File.expand_path('../../lib', __FILE__)
require 'auth/version'
require 'auth/backends/base'
require 'auth/backends/mongo_db'
require 'auth/backends/mysql_db'
require 'auth/server'
require 'auth/client'
require 'auth/cli'


