# -*- encoding: utf-8 -*-
require File.expand_path '../lib/common/version', __FILE__

Gem::Specification.new do |gem|
  gem.authors       = %W{João Pereira}
  gem.email         = %W{joaodrp@gmail.com}
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = "http://github.com/joaodrp/visor"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "visor-common"
  gem.require_paths = %W{lib}
  gem.version       = Visor::Common::VERSION
end
