#
# Extends the Logger Class
#
class Logger
  # Make Rack::CommonLogger accept a Logger instance
  # without raising undefined method `write' for #<Logger:0x007fc12db61778>
  alias write <<
end
