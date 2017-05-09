# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)
Gem::Specification.new do |s|
  s.name        = "jqgrid-rails3"
  s.version     = "0.44"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["2dconcept"]
  s.email       = ["etiennevt@gmail.com"]
  s.homepage    = "https://github.com/springbok/jqgrid-rails3"
  s.summary     = "jQuery grid plugin for rails3"
  s.description = "jQuery grid plugin for rails3"

  s.required_rubygems_version = ">= 1.3.6"

  s.files        = Dir.glob("{lib,public}/**/*") + %w(MIT-LICENSE README.rdoc Rakefile)
  s.require_paths = [%q{lib}]
end
