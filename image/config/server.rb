#require File.expand_path('../../image', __FILE__)

conf      = Visor::Common::Config.load_config
meta_host = conf[:visor_meta][:bind_host]
meta_port = conf[:visor_meta][:bind_port]
log_level = conf[:visor_api][:log_level]

logger.level      = (log_level == 'INFO' ? 1 : 0)
config['vms']     = Visor::Image::Meta.new(host: meta_host, port: meta_port)
config['configs'] = conf[:visor_store]
