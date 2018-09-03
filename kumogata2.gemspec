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

  spec.add_dependency 'aws-sdk', '~> 3.0'
  spec.add_dependency 'coderay', '~> 1.1'
  spec.add_dependency 'diffy', '~> 3.2'
  spec.add_dependency 'hashie', '~> 3.5'
  spec.add_dependency 'highline', '~> 2.0'
  spec.add_dependency 'term-ansicolor', '~> 1.6'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'kumogata2-plugin-ruby', '~> 0.1'
end
