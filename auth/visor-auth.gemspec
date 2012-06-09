require File.expand_path '../lib/auth/version', __FILE__

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY

  s.name    = 'visor-auth'
  s.version = Visor::Auth::VERSION

  s.authors = 'João Pereira'
  s.email   = 'joaodrp@gmail.com'

  s.homepage = 'http://cvisor.org'

  s.description = 'The VISOR Auth System, responsible for maintaining VISOR users accounts.'
  s.summary     = 'VISOR: Virtual Images Management Service for Cloud Infrastructures'

  s.executables        = ['visor-auth']
  s.default_executable = 'visor-auth'

  s.files      = Dir["lib/**/*.rb"]
  s.test_files = Dir["spec/**/*_spec.rb"]

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'yard'

  s.add_runtime_dependency 'mongo'
  s.add_runtime_dependency 'bson_ext'
  s.add_runtime_dependency 'mysql2'
  s.add_runtime_dependency 'sinatra'
  s.add_runtime_dependency 'thin'
end
