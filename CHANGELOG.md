# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
