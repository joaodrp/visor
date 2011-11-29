module Cbolt

  # Version
  #
  VERSION = '0.0.0'

  # Require external libraries
  #
  require 'mongo'
  require 'json'
  require 'active_model'

  # Require libraries
  #
  $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

  require 'registry/exceptions'
  require 'registry/extensions/hash'
  require 'registry/extensions/string'
  require 'registry/backends/backend'
  require 'registry/backends/mongo'
  #require 'registry/image'

end
