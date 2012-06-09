require File.expand_path '../lib/image/version', __FILE__

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY

  s.name    = 'visor-image'
  s.version = Visor::Image::VERSION

  s.authors = 'João Pereira'
  s.email   = 'joaodrp@gmail.com'

  s.homepage = 'http://cvisor.org'

  s.description = 'The VISOR Image System, the VISOR front-end API.'
  s.summary     = 'VISOR: Virtual Images Management Service for Cloud Infrastructures'

  s.files      = Dir["lib/**/*.rb"]
  s.test_files = Dir["spec/**/*_spec.rb"]

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'yard'

  s.add_runtime_dependency 'goliath'
  s.add_runtime_dependency 'em-http-request'
  s.add_runtime_dependency 's3-restful'
  s.add_runtime_dependency 'progressbar'
end
