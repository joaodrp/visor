#!/usr/bin/env rake
require "bundler"
require 'rake/testtask'
require 'fileutils'

source = "*/lib/**/*.rb */lib/*/**/*.rb"
spec  = "*/spec/*.rb */spec/**/*.rb"

files = "docs/INSTALLATION.md docs/CONFIGURATION_FILE.md docs/USING_VISOR.md"

Rake::TestTask.new(:all) do |t|
  t.libs.push "lib"
  t.test_files = FileList['spec/*/*_spec.rb']
end

desc "Count lines of source .rb files"
task :lines do
  system "find #{image+ "" + spec} -name '*.rb' | xargs wc -l"
end

desc "Generate YARD documentation"
task :ydoc do
  output = "../gh-pages/visor/"
  system "yardoc #{source} -o #{output} --protected -b #{output}.yardoc --title VISoR --main README.md --files #{files}"
end

desc "Generate YARD documentation and commit to gh-pages branch"
task :ydoc_commit do
  output = "../gh-pages/visor/"
  system "yardoc #{source} -o #{output} --protected -b #{output}.yardoc --title VISoR --main README.md --files #{files}"
  system "cd #{output} && git add . && git commit -am 'documentation updated' && git push origin gh-pages"
end

task :default => :list

task :list do
  system 'rake -T'
end

# cd #{output} && yard graph --protected --full --dependencies | dot -T pdf -o diagram.pdf
