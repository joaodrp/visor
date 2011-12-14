module Visor

  # Version
  #
  VERSION = '0.0.0'

  # Require external libraries
  #
  #require 'mongo'
  #require 'mysql2'

  # Require standard libraries
  #
  require 'json' #TODO: try Yajl
  require 'securerandom'

  # Require libraries
  #
  $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

  require 'registry/client'
  require 'registry/exceptions'
  require 'registry/extensions/hash'
  require 'registry/extensions/string'
  require 'registry/backends/base'
  require 'registry/backends/mongo_db'
  require 'registry/backends/mysql_db'
end
