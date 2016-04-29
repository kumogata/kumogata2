# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kumogata2/version'

Gem::Specification.new do |spec|
  spec.name          = 'kumogata2'
  spec.version       = Kumogata2::VERSION
  spec.authors       = ['Genki Sugawara']
  spec.email         = ['sugawara@cookpad.com']

  spec.summary       = %q{Kumogata2 is a tool for AWS CloudFormation.}
  spec.description   = %q{Kumogata2 is a tool for AWS CloudFormation.}
  spec.homepage      = 'https://github.com/winebarrel/kumogata2'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk', '~> 2.3.0'
  spec.add_dependency 'coderay'
  spec.add_dependency 'diffy'
  spec.add_dependency 'hashie'
  spec.add_dependency 'highline'
  spec.add_dependency 'term-ansicolor'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'kumogata2-plugin-ruby'
end
