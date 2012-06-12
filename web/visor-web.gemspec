require File.expand_path '../lib/web/version', __FILE__

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY

  s.name    = 'visor-web'
  s.version = Visor::Web::VERSION

  s.authors = 'João Pereira'
  s.email   = 'joaodrp@gmail.com'

  s.homepage = 'http://cvisor.org'

  s.description = 'The VISOR Web System, a Web application dashboard with VISOR statistical information.'
  s.summary     = 'VISOR: Virtual Images Management Service for Cloud Infrastructures'

  s.executables        = ['visor-web']
  s.default_executable = 'visor-web'

  s.files      = Dir["lib/**/*.rb"]
  s.test_files = Dir["spec/**/*_spec.rb"]

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'yard'

  s.add_runtime_dependency 'visor-common'
  s.add_runtime_dependency 'sinatra'
  s.add_runtime_dependency 'thin'
  s.add_runtime_dependency 'google_visualr'

  s.required_ruby_version = '>= 1.9.2'
  s.post_install_message = %q[

****************************** VISOR ******************************

visor-web was successfully installed!

Generate the VISOR configuration file for this machine (if not already done) by running the 'visor-config' command.

*******************************************************************

]
end
