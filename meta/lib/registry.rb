module Visor

  #TODO: try Yajl

  # Require libraries
  #
  $:.unshift(File.join(File.dirname(__FILE__), '../../common/lib'))

  require 'common'

  $:.unshift(File.join(File.dirname(__FILE__), '../lib'))

  require 'registry/client'
  require 'registry/api'
  require 'registry/backends/base'
  require 'registry/backends/mongo_db'
  require 'registry/backends/mysql_db'
end
