require File.expand_path '../lib/common/version', __FILE__

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY

  s.name    = 'visor-common'
  s.version = Visor::Common::VERSION

  s.authors = 'João Pereira'
  s.email   = 'joaodrp@gmail.com'

  s.homepage = 'http://cvisor.org'

  s.description = 'The VISOR Common System, a set of utility methods.'
  s.summary     = 'VISOR: Virtual Images Management Service for Cloud Infrastructures'

  s.executables        = ['visor-config']
  s.default_executable = 'visor-config'

  s.files      = Dir["lib/**/*.rb"]
  s.test_files = Dir["spec/**/*_spec.rb"]

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'yard'

  s.required_ruby_version = '>= 1.9.2'
end
