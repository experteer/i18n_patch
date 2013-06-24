# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'i18n_patch/version'

Gem::Specification.new do |spec|
  spec.name          = "i18n_patch"
  spec.version       = I18nPatch::VERSION
  spec.authors       = ["Pavlo Masko"]
  spec.email         = ["pavlo.masko@experteer.com"]
  spec.description   = %q{Internationalization gem}
  spec.summary       = %q{At a moment only path switcher}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord"," =  2.3.3"
  spec.add_dependency "actionpack"," =  2.3.3"
  spec.add_development_dependency "rspec","~> 2.3"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
