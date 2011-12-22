module Visor

  # Require standard libraries
  #

  # Require libraries
  #
  $:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

  require 'common/exception'
  require 'common/config'
  require 'common/extensions/hash'
  require 'common/extensions/string'
  require 'common/extensions/logger'
end
