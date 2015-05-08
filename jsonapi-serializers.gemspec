# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonapi/serializers/version'

Gem::Specification.new do |spec|
  spec.name          = "jsonapi-serializers"
  spec.version       = JSONAPI::Serializers::VERSION
  spec.authors       = ["Mike Fotinakis"]
  spec.email         = ["mike@fotinakis.com"]
  spec.summary       = %q{Pure Ruby serializers conforming to the JSON:API spec.}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
