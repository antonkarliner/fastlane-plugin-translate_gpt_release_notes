![logo](images/logo.png)

# translate-gpt-release-notes plugin
[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-translate_gpt_release_notes)
[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-translate_gpt_release_notes.svg)](https://badge.fury.io/rb/fastlane-plugin-translate_gpt_release_notes)

## Getting Started

This project is a [fastlane](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-translate_gpt_release_notes`, add it to your project by running:

```bash
fastlane add_plugin translate_gpt_release_notes
```

### Requirements

- Ruby >= 3.1
- API key for at least one supported translation provider

**Note**: This plugin requires Ruby 3.1 or higher to ensure compatibility with the latest security patches in nokogiri.

## About translate-gpt-release-notes

`translate-gpt-release-notes` is a fastlane plugin that allows you to translate release notes or changelogs for iOS and Android apps using multiple AI translation providers. Based on [translate-gpt by ftp27](https://github.com/ftp27/fastlane-plugin-translate_gpt).

### Supported Translation Providers

The plugin now supports **4 translation providers**, giving you flexibility to choose based on cost, quality, and availability:

| Provider | Best For | Quality | Cost | Speed |
|----------|----------|---------|------|-------|
| **OpenAI GPT** | General purpose, flexible translations | ⭐⭐⭐⭐⭐ | $$$ | Fast |
| **Anthropic Claude** | High-quality, nuanced translations | ⭐⭐⭐⭐⭐ | $$$ | Medium |
| **Google Gemini** | Cost-effective, high-volume translations | ⭐⭐⭐⭐ | $ | Fast |
| **DeepL** | European languages, specialized translation | ⭐⭐⭐⭐⭐ | $$ | Fast |

## How it works

`translate-gpt-release-notes` takes the changelog file for the master locale (default: en-US), detects other locales based on the fastlane metadata folder structure, translates the changelog to all other languages using your chosen AI provider, and creates localized `.txt` changelog files in their respective folders.

## Quick Start

### 1. Configure your API key

Choose your preferred provider and set the corresponding environment variable:

```bash
# Option 1: OpenAI (default)
export OPENAI_API_KEY='your-openai-api-key'
# Or use the legacy variable (still supported)
export GPT_API_KEY='your-openai-api-key'

# Option 2: Anthropic Claude
export ANTHROPIC_API_KEY='your-anthropic-api-key'

# Option 3: Google Gemini
export GEMINI_API_KEY='your-gemini-api-key'

# Option 4: DeepL
export DEEPL_API_KEY='your-deepl-api-key'
```

### 2. Use in your Fastfile

```ruby
lane :translate_release_notes do
  translate_gpt_release_notes(
    master_locale: 'en-US',
    platform: 'ios',
    context: 'This is an app about cute kittens'
  )
end
```

## Provider Selection

### Default Provider

By default, the plugin uses **OpenAI** as the translation provider. This ensures backward compatibility with existing setups.

### Selecting a Provider

You can explicitly select a provider using the `provider` parameter:

```ruby
# Use Anthropic Claude
translate_gpt_release_notes(
  provider: 'anthropic',
  master_locale: 'en-US',
  platform: 'ios'
)

# Use Google Gemini
translate_gpt_release_notes(
  provider: 'gemini',
  master_locale: 'en-US',
  platform: 'ios'
)

# Use DeepL
translate_gpt_release_notes(
  provider: 'deepl',
  master_locale: 'en-US',
  platform: 'ios'
)
```

Or set the default provider via environment variable:

```bash
export TRANSLATION_PROVIDER='anthropic'
```

## Usage Examples by Provider

### OpenAI (Default)

```ruby
translate_gpt_release_notes(
  provider: 'openai',              # Optional, this is the default
  openai_api_key: 'sk-...',        # Or use OPENAI_API_KEY env var
  model_name: 'gpt-5.2',           # Default model
  service_tier: 'flex',            # Options: auto, default, flex, priority
  temperature: 0.5,                # 0-2, lower = more deterministic
  master_locale: 'en-US',
  platform: 'ios',
  context: 'Fitness tracking app'
)
```

### Anthropic Claude

```ruby
translate_gpt_release_notes(
  provider: 'anthropic',
  anthropic_api_key: 'sk-ant-...', # Or use ANTHROPIC_API_KEY env var
  model_name: 'claude-sonnet-4.5', # Default model
  temperature: 0.5,                # 0-1 for Anthropic
  master_locale: 'en-US',
  platform: 'ios',
  context: 'Finance management app'
)
```

### Google Gemini

```ruby
translate_gpt_release_notes(
  provider: 'gemini',
  gemini_api_key: '...',           # Or use GEMINI_API_KEY env var
  model_name: 'gemini-2.5-flash',  # Default model
  temperature: 0.5,                # 0-1 for Gemini
  master_locale: 'en-US',
  platform: 'android',
  context: 'Social media app'
)
```

### DeepL

```ruby
translate_gpt_release_notes(
  provider: 'deepl',
  deepl_api_key: '...',            # Or use DEEPL_API_KEY env var
  formality: 'less',               # Options: default, more, less
  master_locale: 'en-US',
  platform: 'ios',
  context: 'Casual gaming app'
)
```

**Note**: DeepL automatically detects free vs paid API keys (free keys end with `:fx`) and uses the appropriate endpoint.

## Glossary Support (Experimental)

> **Note**: Glossary support is an experimental feature. If you encounter any issues, please [open an issue on GitHub](https://github.com/antonkarliner/fastlane-plugin-translate_gpt_release_notes/issues).

The glossary feature ensures consistent translation of app-specific terms (screen names, feature names, UI labels) across all locales. Instead of letting the AI provider guess how to translate "Brew Diary" or "Cupping Score", the glossary provides exact translations extracted from your existing localization files.

### How It Works

1. The plugin loads glossary terms from a JSON file and/or a directory of localization files
2. Before each translation, it fuzzy-matches terms from the glossary against the source text
3. Only relevant terms are included in the translation prompt (keeping it concise)
4. The AI is instructed to use glossary terms as **reference translations** and apply appropriate grammatical forms (declension, conjugation, agreement) as needed — so translations sound natural in inflected languages like Russian, German, or Finnish rather than copying terms verbatim
5. Each provider uses the glossary differently:
   - **OpenAI**: Glossary terms are sent as a system message for strong instruction following
   - **Anthropic / Gemini**: Glossary terms are included in the translation prompt
   - **DeepL**: Glossary terms are passed via the `context` parameter

### Supported Localization Formats

| Format | Extension | Common Use |
|--------|-----------|------------|
| ARB (Application Resource Bundle) | `.arb` | Flutter |
| Apple Strings | `.strings` | iOS / macOS |
| Android XML | `.xml` | Android |
| JSON i18n | `.json` | Web / React / Vue |
| XLIFF | `.xliff`, `.xlf` | Cross-platform |

### Using Localization Directory (Recommended)

Point the plugin at your existing localization directory. It will auto-detect the format and extract terms:

```ruby
# Flutter project — use the l10n directory directly
translate_gpt_release_notes(
  master_locale: 'en-US',
  platform: 'ios',
  glossary_dir: '../lib/l10n'
)

# iOS project — use .lproj directories
translate_gpt_release_notes(
  master_locale: 'en-US',
  platform: 'ios',
  glossary_dir: '../MyApp/Resources'
)

# Android project — use res/values directories
translate_gpt_release_notes(
  master_locale: 'en-US',
  platform: 'android',
  glossary_dir: '../app/src/main/res'
)
```

### Using a Curated JSON Glossary File

For maximum control, create a JSON glossary file with exact translations per locale:

```json
{
  "Home Screen": {
    "de": "Startbildschirm",
    "fr": "Ecran d'accueil",
    "es": "Pantalla de inicio",
    "ja": "ホーム画面"
  },
  "Brew Diary": {
    "de": "Brautagebuch",
    "fr": "Journal de brassage"
  }
}
```

```ruby
translate_gpt_release_notes(
  master_locale: 'en-US',
  platform: 'ios',
  glossary: 'path/to/glossary.json'
)
```

### Combining Both Sources

You can use both a curated glossary file and a localization directory. The curated file takes priority for overlapping terms:

```ruby
translate_gpt_release_notes(
  master_locale: 'en-US',
  platform: 'ios',
  glossary: 'fastlane/glossary.json',
  glossary_dir: '../lib/l10n'
)
```

### Fuzzy Matching

The plugin uses smart fuzzy matching to find relevant glossary terms in the source text:

- **Full substring match**: "Home Screen" matches if it appears exactly in the text
- **Multi-word match**: A term matches if 2 or more significant words (4+ characters, excluding common English stopwords) appear in the text
- **Filtering**: Terms shorter than 4 characters, longer than 80 characters, or consisting of common stopwords are excluded

This keeps the glossary concise and avoids flooding the AI provider with irrelevant terms.

## Options

### Core Options

| Key | Description | Environment Variable | Default |
|-----|-------------|---------------------|---------|
| `provider` | Translation provider to use (`openai`, `anthropic`, `gemini`, `deepl`) | `TRANSLATION_PROVIDER` | `openai` |
| `master_locale` | Master language/locale for the source texts | `MASTER_LOCALE` | `en-US` |
| `platform` | Platform (`ios` or `android`) | `PLATFORM` | `ios` |
| `context` | Context for translation to improve accuracy | `GPT_CONTEXT` | - |
| `glossary` | Path to a curated JSON glossary file | `GLOSSARY_PATH` | - |
| `glossary_dir` | Path to localization files directory for auto-extracting glossary | `GLOSSARY_DIR` | - |

### Provider-Specific API Keys

| Key | Description | Environment Variable |
|-----|-------------|---------------------|
| `openai_api_key` | OpenAI API key | `OPENAI_API_KEY` or `GPT_API_KEY` |
| `anthropic_api_key` | Anthropic API key | `ANTHROPIC_API_KEY` |
| `gemini_api_key` | Google Gemini API key | `GEMINI_API_KEY` |
| `deepl_api_key` | DeepL API key | `DEEPL_API_KEY` |

### OpenAI-Specific Options

| Key | Description | Environment Variable | Default |
|-----|-------------|---------------------|---------|
| `model_name` | OpenAI model to use | `GPT_MODEL_NAME` | `gpt-5.2` |
| `service_tier` | Service tier: `auto`, `default`, `flex`, `priority` | `GPT_SERVICE_TIER` | - |
| `temperature` | Sampling temperature (0-2) | `GPT_TEMPERATURE` | `0.5` |
| `request_timeout` | Timeout in seconds (auto-bumped to 900s for flex) | `GPT_REQUEST_TIMEOUT` | `30` |

### Anthropic-Specific Options

| Key | Description | Environment Variable | Default |
|-----|-------------|---------------------|---------|
| `model_name` | Anthropic model to use | `ANTHROPIC_MODEL_NAME` | `claude-sonnet-4.5` |
| `temperature` | Sampling temperature (0-1) | `ANTHROPIC_TEMPERATURE` | `0.5` |
| `request_timeout` | Timeout in seconds | `ANTHROPIC_REQUEST_TIMEOUT` | `60` |

### Google Gemini-Specific Options

| Key | Description | Environment Variable | Default |
|-----|-------------|---------------------|---------|
| `model_name` | Gemini model to use | `GEMINI_MODEL_NAME` | `gemini-2.5-flash` |
| `temperature` | Sampling temperature (0-1) | `GEMINI_TEMPERATURE` | `0.5` |
| `request_timeout` | Timeout in seconds | `GEMINI_REQUEST_TIMEOUT` | `60` |

### DeepL-Specific Options

| Key | Description | Environment Variable | Default |
|-----|-------------|---------------------|---------|
| `formality` | Formality level: `default`, `more`, `less` | `DEEPL_FORMALITY` | `default` |
| `request_timeout` | Timeout in seconds | `DEEPL_REQUEST_TIMEOUT` | `30` |

## Authentication

### Environment Variables (Recommended)

The recommended approach is to set API keys via environment variables:

```bash
export OPENAI_API_KEY='sk-...'
export ANTHROPIC_API_KEY='sk-ant-...'
export GEMINI_API_KEY='...'
export DEEPL_API_KEY='...'
```

### Direct Parameters

Alternatively, pass API keys directly (useful for CI/CD with secrets):

```ruby
translate_gpt_release_notes(
  provider: 'anthropic',
  anthropic_api_key: ENV['ANTHROPIC_API_KEY'],
  master_locale: 'en-US',
  platform: 'ios'
)
```

### Multiple Providers Configuration

You can configure multiple providers simultaneously and switch between them:

```bash
# Set up all providers
export OPENAI_API_KEY='sk-...'
export ANTHROPIC_API_KEY='sk-ant-...'
export GEMINI_API_KEY='...'

# Default to Gemini for cost savings
export TRANSLATION_PROVIDER='gemini'
```

## Migration Guide

### From Single-Provider Setup (v0.1.x)

If you're upgrading from a previous version that only supported OpenAI:

1. **No breaking changes** - Your existing setup will continue to work
2. **Existing `GPT_API_KEY` still works** - No need to rename your environment variable
3. **Default provider is OpenAI** - All existing configurations work unchanged

Optional improvements you can make:
- Rename `GPT_API_KEY` to `OPENAI_API_KEY` for clarity (both work)
- Set `TRANSLATION_PROVIDER` if you want to experiment with other providers
- Try different providers for different lanes (e.g., Gemini for development, Claude for production)

### Example Migration

**Before:**
```ruby
translate_gpt_release_notes(
  api_token: ENV['GPT_API_KEY'],
  model_name: 'gpt-5.2',
  master_locale: 'en-US'
)
```

**After** (still works, but cleaner):
```ruby
translate_gpt_release_notes(
  provider: 'openai',
  master_locale: 'en-US'
)
```

## Important Notes

### Android 500 Character Limit

Android has a hard limit of 500 characters for changelogs. The plugin enforces this in two layers:

1. **Prompt constraint**: For AI providers, the limit is included near the top of the prompt (alongside core instructions) with explicit wording that the model must count carefully and shorten or summarize if needed. This positions it as a hard constraint rather than an afterthought.
2. **Safety-net truncation**: All providers (including DeepL) truncate the result and log a warning if the model still exceeds 500 characters despite the prompt.

If you frequently hit the limit, consider shortening your master locale changelog.

### iOS Character Limit

iOS has a limit of 4000 characters, which is rarely an issue for release notes.

### Cost Considerations

All AI translation APIs cost money. Consider these tips:

- Use `service_tier: 'flex'` with OpenAI for lower prices (trades latency for cost)
- Google Gemini is generally the most cost-effective option
- DeepL offers competitive pricing for European languages
- The plugin skips translation if the source file hasn't changed (tracked via `last_successful_run.txt`)

### Service Tiers (OpenAI)

| Tier | Description | Use Case |
|------|-------------|----------|
| `auto` | Automatic tier selection | General use |
| `default` | Standard processing | Urgent translations |
| `flex` | Lower cost, higher latency | Non-urgent translations |
| `priority` | Premium processing | Critical releases |

**Note**: When using `flex`, the plugin automatically increases `request_timeout` to 900 seconds if set lower.

## Troubleshooting

### "No translation provider credentials configured"

**Cause**: No API keys are set for any provider.

**Solution**: Set at least one provider's API key:
```bash
export OPENAI_API_KEY='your-key-here'
```

### "Provider 'X' has no credentials"

**Cause**: You specified a provider but haven't configured its API key.

**Solution**: Either configure the provider's API key or switch to a provider with configured credentials.

### "Invalid provider 'X'"

**Cause**: The provider name is not recognized.

**Solution**: Use one of the valid provider names: `openai`, `anthropic`, `gemini`, `deepl`.

### Translations Exceed Android Character Limit

**Cause**: The translated text is longer than 500 characters.

**Solutions**:
1. Shorten your source changelog — the most reliable fix
2. All providers will truncate automatically if the limit is exceeded (with a warning), but this may cut mid-sentence
3. For AI providers, the prompt strongly instructs the model to stay within the limit and shorten if needed

### API Timeout Errors

**Cause**: The translation request is taking too long.

**Solutions**:
1. Increase `request_timeout` parameter
2. For OpenAI flex tier, timeout is automatically increased to 900s
3. Consider using a faster provider (Gemini or DeepL)

### Slow Translations with Flex Tier

**Cause**: Flex tier trades latency for lower cost.

**Solution**: This is expected behavior. If speed is critical, use `service_tier: 'default'` or `service_tier: 'priority'`.

### Glossary Terms Not Being Applied

**Cause**: The fuzzy matching didn't find your terms in the source text.

**Solutions**:
1. Check that terms are at least 4 characters long
2. For multi-word terms, at least 2 significant words (4+ chars, non-stopword) must appear in the text
3. Use `glossary` with a curated JSON file for critical terms
4. If using `glossary_dir`, verify the localization files contain translations for the target locale

### Too Many Glossary Terms Matched

**Cause**: The localization directory contains many short or generic terms.

**Solutions**:
1. Use a curated JSON glossary file (`glossary`) with only the most important terms instead of pointing at the full localization directory
2. Terms longer than 80 characters (full sentences) are automatically excluded
3. Common English stopwords are excluded from matching

## Provider Comparison Details

### When to Use Each Provider

**OpenAI GPT**
- ✅ Best for general-purpose translations
- ✅ Flexible and customizable
- ✅ Supports service tiers for cost control
- ❌ Can be expensive for high volume

**Anthropic Claude**
- ✅ Highest quality nuanced translations
- ✅ Excellent for complex or technical content
- ✅ Strong reasoning capabilities
- ❌ Slower than other options
- ❌ Higher cost

**Google Gemini**
- ✅ Most cost-effective
- ✅ Fast response times
- ✅ Good quality for standard content
- ❌ May struggle with very nuanced content

**DeepL**
- ✅ Best for European languages
- ✅ Purpose-built for translation
- ✅ Formality control
- ❌ Limited language support compared to AI providers
- ❌ May not handle app-specific context as well

## Issues and Feedback

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide. For any other issues and feedback about this plugin, please submit it to this repository.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).

## Contributing

If you'd like to contribute to this plugin, please fork the repository and make your changes. When you're ready, submit a pull request explaining your changes.

## License

This action is released under the [MIT License](LICENSE).
