#!/usr/bin/env rake
require "bundler/gem_tasks"
require 'rake/testtask'
require 'fileutils'

api         = "api/lib/**/*.rb api/lib/api/**/*.rb"
api_spec    = " api/spec/*.rb api/spec/**/*.rb"
meta        = "meta/lib/**/*.rb meta/lib/meta/**/*.rb"
meta_spec   = " meta/spec/*.rb meta/spec/**/*.rb"
common      = "common/lib/**/*.rb common/lib/common/**/*.rb"
common_spec = " common/spec/*.rb common/spec/**/*.rb"
files       = ""

Rake::TestTask.new(:all) do |t|
  t.libs.push "lib"
  t.test_files = FileList['spec/*/*_spec.rb']
end

desc "Count lines of source .rb files"
task :lines do
  system "find #{api+api_spec} #{meta+meta_spec} #{common+common_spec} -name '*.rb' | xargs wc -l"
end

desc "Generate YARD documentation"
task :ydoc do
  output = "~/workspace/gh-pages/visor/"
  system "yardoc #{api} #{meta} #{common} -o #{output} --protected --no-save --title VISoR --main README.md - #{files}"
  system "cd #{output} && git add . && git commit -am 'documentation updated' && git push origin gh-pages"
end

task :default => :list

task :list do
  system 'rake -T'
end
