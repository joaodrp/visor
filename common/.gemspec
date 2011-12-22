lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'bundler/version'

Gem::Specification.new do |s|
  s.name        = "visor-common"
  s.version     = Bundler::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Joao Pereira"]
  s.email       = ["joaodrp@gmail.com"]
  s.homepage    = "http://github.com/joaodrp/visor"
  s.summary     = ""
  s.description = ""

  #s.required_rubygems_version = ">= 1.3.6"
  #s.rubyforge_project         = "bundler"
  #
  #s.add_development_dependency "rspec"

  s.files        = Dir.glob("{bin,lib}/**/*")
  #s.executables  = ['bundle']
  s.require_path = 'lib'
end
