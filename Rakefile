#!/usr/bin/env rake
require "bundler/gem_tasks"
require 'rake/testtask'
require 'fileutils'

image  = "image/lib/**/*.rb image/lib/image/**/*.rb"
meta   = "meta/lib/**/*.rb meta/lib/meta/**/*.rb"
common = "common/lib/**/*.rb common/lib/common/**/*.rb"

image_spec  = " image/spec/*.rb image/spec/**/*.rb"
meta_spec   = " meta/spec/*.rb meta/spec/**/*.rb"
common_spec = " common/spec/*.rb common/spec/**/*.rb"

files = ""

Rake::TestTask.new(:all) do |t|
  t.libs.push "lib"
  t.test_files = FileList['spec/*/*_spec.rb']
end

desc "Count lines of source .rb files"
task :lines do
  system "find #{image+api_spec} #{meta+meta_spec} #{common+common_spec} -name '*.rb' | xargs wc -l"
end

desc "Generate YARD documentation"
task :ydoc do
  output = "~/workspace/gh-pages/visor/"
  system "yardoc #{image} #{meta} #{common} -o #{output} --protected -b #{output}.yardoc --title VISoR --main README.md - #{files}"
  system "cd #{output} && git add . && git commit -am 'documentation updated' && git push origin gh-pages"
end

task :default => :list

task :list do
  system 'rake -T'
end

# cd #{output} && yard graph --protected --full --dependencies | dot -T pdf -o diagram.pdf
