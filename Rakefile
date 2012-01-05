#!/usr/bin/env rake
require "bundler/gem_tasks"
require 'rake/testtask'
require 'fileutils'

meta = "meta/lib/**/*.rb meta/lib/meta/**/*.rb"
common = "common/lib/**/*.rb common/lib/common/**/*.rb"
files = "- "

Rake::TestTask.new(:all) do |t|
  t.libs.push "lib"
  t.test_files = FileList['spec/*/*_spec.rb']
end

desc "Count lines of source .rb files"
task :lines do
  system "find #{meta} #{common} -name '*.rb' | xargs wc -l"
end

desc "Generate YARD documentation"
task :ydoc do
  output = "~/workspace/gh-pages/visor/"
  system "yardoc #{meta} #{common} -o #{output} --protected --no-save --title VISoR --main README.md  #{files}"
  system "cd #{output} && git add . && git commit -am 'documentation updated' && git push origin gh-pages"
end

task :default => :list

task :list do
  system 'rake -T'
end
