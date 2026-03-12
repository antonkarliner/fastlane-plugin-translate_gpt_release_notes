# fastlane-plugin-translate_gpt_release_notes

A fastlane plugin that translates app release notes using AI providers: OpenAI, Anthropic Claude, Google Gemini, or DeepL.

## Project Structure

```
lib/fastlane/plugin/translate_gpt_release_notes/
├── actions/
│   └── translate_gpt_release_notes_action.rb   # Main action entry point
├── helper/
│   ├── translate_gpt_release_notes_helper.rb   # Core translation logic
│   ├── credential_resolver.rb                  # API key resolution
│   ├── glossary_loader.rb                      # Glossary file parsing
│   └── providers/
│       ├── base_provider.rb
│       ├── provider_factory.rb
│       ├── openai_provider.rb
│       ├── anthropic_provider.rb
│       ├── gemini_provider.rb
│       └── deepl_provider.rb
└── version.rb
```

## Development

- Ruby 3.2.2 (see `.ruby-version`)
- Run tests: `bundle exec rspec`
- Run linter: `bundle exec rubocop`
- Run both: `bundle exec rake` (default task)

## Versioning

Version is in `lib/fastlane/plugin/translate_gpt_release_notes/version.rb`. When releasing, bump the version there and update the CHANGELOG.

## Key Concepts

- **Providers**: OpenAI, Anthropic, Gemini, DeepL — each in its own file under `providers/`. Add new providers by subclassing `BaseProvider` and registering in `ProviderFactory`.
- **Glossary**: Optional JSON glossary file or directory of localization files (ARB, .strings, .xml, .json, .xliff) to enforce consistent terminology.
- **Platforms**: Supports both iOS (`fastlane/metadata/<locale>/release_notes.txt`) and Android (`fastlane/metadata/android/<locale>/changelogs/<version>.txt`).
- **Incremental**: Skips translation if source file hasn't changed since last run (tracked in `last_successful_run.txt`).

## Dependencies

Runtime: `ruby-openai`, `anthropic`, `deepl-rb`, `loco_strings`, `nokogiri`, `openssl`
Dev: `rspec`, `rubocop 1.12.1`, `simplecov`
