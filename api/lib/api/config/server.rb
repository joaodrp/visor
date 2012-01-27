#require File.expand_path('../../api', __FILE__)

conf      = Visor::Common::Config.load_config
meta_host = conf[:visor_meta][:bind_host]
meta_port = conf[:visor_meta][:bind_port]

config['vms']     = Visor::API::Meta.new(host: meta_host, port: meta_port)
config['options'] = conf[:visor_store]
