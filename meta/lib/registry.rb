module Cbolt

  # Version
  #
  VERSION = '0.0.0'

  # Require external libraries
  #
  require 'mongo'
  require 'mysql2'

  # Require standard libraries
  #
  require 'json' #TODO: try Yajl

  # Require libraries
  #
  $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

  require 'registry/exceptions'
  require 'registry/extensions/hash'
  require 'registry/extensions/string'
  require 'registry/backends/backend'
  require 'registry/backends/mongo_db'
  require 'registry/backends/mysql_db'
end