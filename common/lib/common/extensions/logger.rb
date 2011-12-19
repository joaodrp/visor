#
# Extends the Logger Class
#
# Make Rack::CommonLogger accept a Logger instance
# without raising undefined method `write' for #<Logger:0x007fc12db61778>
#
class Logger
  alias write <<
end
