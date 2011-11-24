module Registry

  # Version
  #
  VERSION = '0.0.0'

  # Require external libraries
  #
  require 'mongo'
  require 'json'

  # Require libraries
  #
  $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

  require 'registry/exceptions'
  require 'registry/extensions/hash'
  require 'registry/extensions/string'
  require 'registry/backends/backend'
  require 'registry/backends/mongo'

end
