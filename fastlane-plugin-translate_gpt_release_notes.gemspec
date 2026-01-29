lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-translate_gpt_release_notes'
  spec.version       = '0.2.0'
  spec.author        = 'Anton Karliner'
  spec.email         = 'anton@karliner.pro'

  spec.summary       = 'Translate release notes using AI providers: OpenAI, Claude, Gemini, or DeepL'
  spec.homepage      = "https://github.com/antonkarliner/fastlane-plugin-translate_gpt_release_notes"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/antonkarliner/fastlane-plugin-translate_gpt_release_notes"
  spec.metadata["github_repo"] = "https://github.com/antonkarliner/fastlane-plugin-translate_gpt_release_notes"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.1'

  spec.add_runtime_dependency 'ruby-openai', '~> 3.7'
  spec.add_runtime_dependency 'loco_strings', '~> 0.1.5'
  spec.add_runtime_dependency 'nokogiri', '>= 1.18.9'

  # Multi-provider support
  spec.add_runtime_dependency 'anthropic', '~> 1.16'
  spec.add_runtime_dependency 'deepl-rb', '~> 3.6'

  # Fix SSL certificate verification issues on macOS with OpenSSL 3.4+
  spec.add_runtime_dependency 'openssl', '>= 3.2.0'

  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fastlane', '>= 2.212.2')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rubocop', '1.12.1')
  spec.add_development_dependency('rubocop-performance')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('simplecov')
end
