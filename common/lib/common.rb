module Visor

  # Require standard libraries
  #

  # Require libraries
  #
  $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

  require 'common/config'
  require 'common/exception'
  require 'common/extensions/hash'
  require 'common/extensions/string'
  require 'common/extensions/logger'
end
