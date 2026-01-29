# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-01-29

### Added

#### Multi-Provider Support
- **Anthropic Claude** provider integration for high-quality translations
  - Default model: `claude-sonnet-4.5`
  - Supports temperature control (0-1)
  - Environment variable: `ANTHROPIC_API_KEY`
  - Parameter: `anthropic_api_key`
  
- **Google Gemini** provider integration for cost-effective translations
  - Default model: `gemini-2.5-flash`
  - Supports temperature control (0-1)
  - Environment variable: `GEMINI_API_KEY`
  - Parameter: `gemini_api_key`
  
- **DeepL** provider integration for specialized translation API
  - Automatic free/paid key detection (free keys end with `:fx`)
  - Formality control (`default`, `more`, `less`)
  - Environment variable: `DEEPL_API_KEY`
  - Parameter: `deepl_api_key`
  - Dedicated handling for Android 500-character limit

#### Provider Selection
- New `provider` parameter to select translation provider
- New `TRANSLATION_PROVIDER` environment variable for default provider selection
- Provider factory pattern for unified provider interface
- Credential resolver supporting multiple simultaneous provider configurations

#### New Parameters
- `provider` - Select translation provider (`openai`, `anthropic`, `gemini`, `deepl`)
- `openai_api_key` - OpenAI API key (alternative to environment variable)
- `anthropic_api_key` - Anthropic API key (alternative to environment variable)
- `gemini_api_key` - Google Gemini API key (alternative to environment variable)
- `deepl_api_key` - DeepL API key (alternative to environment variable)

### Changed
- **OpenAI** remains the default provider for backward compatibility
- Enhanced credential resolution with support for multiple providers
- Improved error messages showing available providers when credentials are missing

### Fixed
- DeepL provider properly handles Android 500-character limit with truncation and warning
- All AI providers now include character limit guidance in translation prompts for Android

### Technical Details
- **Architecture**: New provider abstraction layer with `BaseProvider` class
- **Provider Factory**: Centralized provider instantiation via `ProviderFactory`
- **Credential Resolver**: Multi-provider credential management with priority resolution
- **Backward Compatibility**: Existing `GPT_API_KEY` environment variable still supported

### Migration Guide
If you're upgrading from version 0.1.x:
1. **No breaking changes** - Existing configurations continue to work
2. **Optional**: Set `TRANSLATION_PROVIDER` environment variable to experiment with new providers
3. **Optional**: Add additional provider API keys to enable multi-provider setup
4. All existing parameters (`api_token`, `model_name`, `temperature`, etc.) work unchanged

## [0.1.1] - 2026-01-07

### Added
- `service_tier` option to select OpenAI service tier (auto, default, flex, priority)
- Automatic timeout bump to 900s when using flex tier

### Changed
- Default model updated to `gpt-5.2`

### Fixed
- Version consistency across gemspec and version file

## [0.1.0] - 2025-01-12

### Security
- **CRITICAL**: Updated nokogiri to version 1.18.9 to address multiple CVEs:
  - CVE-2025-6021: XML parser vulnerability
  - CVE-2025-6170: XML processing vulnerability
  - CVE-2025-49794: XML document processing vulnerability
  - CVE-2025-49795: XML entity processing vulnerability
  - CVE-2025-49796: XML parsing vulnerability
- **BREAKING**: Minimum Ruby version requirement increased to 3.1.0

### Changed
- Updated `spec.required_ruby_version` from `'>= 2.6'` to `'>= 3.1'`
- Updated nokogiri dependency from `'>= 1.13.10'` to `'>= 1.18.9'`
- Updated loco_strings dependency to `~> 0.1.5` for better compatibility
- Updated documentation to reflect new Ruby version requirements

### Fixed
- Fixed test specifications to pass proper parameters
- Improved error handling in test suite

### Technical Details
- **Ruby Compatibility**: Now requires Ruby 3.1+ for nokogiri 1.18.9 compatibility
- **Security Patches**: Nokogiri 1.18.9 includes critical security fixes for XML processing
- **Performance**: Ruby 3.1+ provides better performance for the plugin operations
- **Dependencies**: All runtime dependencies verified compatible with Ruby 3.1+

### Migration Guide
If you're upgrading from version 0.0.3:
1. Ensure your Ruby version is 3.1.0 or higher
2. Update your CI/CD pipelines to use Ruby 3.1+
3. Test your fastlane workflows with the updated plugin

## [0.0.3] - 2024-02-03

### Added
- Enhanced error handling for API failures
- Improved logging and debug information

### Fixed
- Fixed issues with locale detection
- Resolved problems with file encoding

## [0.0.2] - 2023-12-09

### Added
- Support for Android changelogs
- Context parameter for better translation accuracy
- Configurable timeout settings

### Changed
- Improved API error handling
- Better file path resolution

## [0.0.1] - 2023-11-26

### Added
- Initial release of fastlane plugin for GPT-powered translation
- Support for iOS release notes translation
- OpenAI GPT API integration
- Multi-language support (French, German, Spanish, etc.)
- Fastlane action `translate_gpt_release_notes`

### Features
- Automatic detection of available locales
- Context-aware translations
- File-based caching to avoid redundant API calls
- Configurable temperature and timeout settings
- Support for custom API tokens via environment variables
