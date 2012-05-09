require File.expand_path '../lib/meta/version', __FILE__

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY

  s.name    = 'visor-meta'
  s.version = Visor::Meta::VERSION

  s.authors = 'João Pereira'
  s.email   = 'joaodrp@gmail.com'

  s.homepage = 'http://cvisor.org'

  s.description = 'The VISOR Meta System, responsible for maintaining image metadata.'
  s.summary     = 'VISOR: Virtual Images Management Service for Cloud Infrastructures'

  s.executables        = ['visor-meta']
  s.default_executable = 'visor-meta'

  s.files      = Dir["lib/**/*.rb"]
  s.test_files = Dir["spec/**/*_spec.rb"]

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rack-test'

  s.add_runtime_dependency 'mongo'
  s.add_runtime_dependency 'bson_ext'
  s.add_runtime_dependency 'mysql2'
  s.add_runtime_dependency 'sinatra'
  s.add_runtime_dependency 'thin'
end
