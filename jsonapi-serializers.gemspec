# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonapi-serializers/version'

Gem::Specification.new do |spec|
  spec.name          = "jsonapi-serializers"
  spec.version       = JSONAPI::Serializer::VERSION
  spec.authors       = ["Mike Fotinakis"]
  spec.email         = ["mike@fotinakis.com"]
  spec.summary       = %q{Pure Ruby readonly serializers for the JSON:API spec.}
  spec.description   = %q{Pure Ruby readonly serializers for the JSON:API spec.}
  spec.homepage      = "https://github.com/fotinakis/jsonapi-serializers"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "factory_girl", "~> 4.5"
  spec.add_development_dependency "activemodel", "~> 4.2"
end
