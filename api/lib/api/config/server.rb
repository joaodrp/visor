require File.expand_path('../../api', __FILE__)

conf = Visor::Common::Config.load_config :meta_server
host = conf[:bind_host]
port = conf[:bind_port]

config['meta'] = Visor::API::Meta.new(host: host, port: port)
