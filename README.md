![logo](images/logo.png)

# translate-gpt-release-notes plugin
[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-translate_gpt_release_notes)
[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-translate_gpt_release_notes.svg)](https://badge.fury.io/rb/fastlane-plugin-translate_gpt_release_notes)

## Getting Started

This project is a [fastlane](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-translate_gpt`, add it to your project by running:

```bash
fastlane add_plugin translate_gpt_release_notes
```

## About translate-gpt-release-notes

`translate-gpt-release-notes` is a fastlane plugin that allows you to translate release notes or changelogs for iOS and Android apps using **OpenAI GPT** or **Google Gemini** APIs. Based on [translate-gpt by ftp27](https://github.com/ftp27/fastlane-plugin-translate_gpt).


## How it works:

`translate-gpt-release-notes` takes the changelog file for master locale (default: en-US), detects other locales based on fastlane metadata folder structure, translates changelog to all other languages using the configured LLM API (OpenAI or Gemini) and creates localized `.txt` changelog files in respective folders.

## Example

The following example demonstrates how to use `translate-gpt-release-notes` in a `Fastfile`

```ruby
  lane :translate_release_notes do
    translate_gpt_release_notes(
      master_locale: 'en-US',
      platform: 'ios',
      context: 'This is an app about cute kittens'
      # other parameters...
    )
end
```

## Options

The following options are available for `translate-gpt-release-notes`:

| Key | Description | Environment Variable | Default |
| --- | --- | --- | --- |
| `llm_provider` | The LLM provider to use: `'openai'` or `'gemini'`. | `LLM_PROVIDER` | `'openai'` |
| `api_token` | The API key for your OpenAI GPT account (used if `llm_provider` is `'openai'`). | `GPT_API_KEY` | `""` |
| `gemini_api_key` | The API key for your Google Gemini account (used if `llm_provider` is `'gemini'`). | `GEMINI_API_KEY` | `""` |
| `model_name` | Name of the LLM model to use (e.g., `'gpt-4-1106-preview'` for OpenAI, `'gemini-1.5-flash'` for Gemini). **Required if `llm_provider` is `'gemini'`.** | `LLM_MODEL_NAME` | `'gpt-4-1106-preview'` |
| `temperature` | What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. | `GPT_TEMPERATURE` | `0.5` |
| `request_timeout` | Timeout for the request in seconds. | `GPT_REQUEST_TIMEOUT` | `30` |
| `master_locale` | Master language/locale for the source texts. | `MASTER_LOCALE` | `'en-US'` |
| `context` | Context for translation to improve accuracy. | `GPT_CONTEXT` | `nil` |
| `platform` | Platform for which to translate (`ios` or `android`). | `PLATFORM` | `'ios'` |

## Example

The following example demonstrates how to use `translate-gpt-release_notes` in a `Fastfile` for both OpenAI (default) and Google Gemini:

```ruby
# Using OpenAI (default)
lane :translate_release_notes_openai do
  translate_gpt_release_notes(
    api_token: ENV['GPT_API_KEY'], # Or provide directly
    master_locale: 'en-US',
    platform: 'ios',
    context: 'This is an app about cute kittens'
    # model_name defaults to 'gpt-4-1106-preview'
  )
end

# Using Google Gemini
lane :translate_release_notes_gemini do
  translate_gpt_release_notes(
    llm_provider: 'gemini',
    gemini_api_key: ENV['GEMINI_API_KEY'], # Or provide directly
    model_name: 'gemini-1.5-flash', # MUST specify a Gemini model
    master_locale: 'en-US',
    platform: 'ios',
    context: 'This is an app about cute kittens'
  )
end
```

## Options

The following options are available for `translate-gpt-release_notes`:

| Key | Description | Environment Variable | Default |
| --- | --- | --- | --- |
| `llm_provider` | The LLM provider to use: `'openai'` or `'gemini'`. | `LLM_PROVIDER` | `'openai'` |
| `api_token` | The API key for your OpenAI GPT account (used if `llm_provider` is `'openai'`). | `GPT_API_KEY` | `""` |
| `gemini_api_key` | The API key for your Google Gemini account (used if `llm_provider` is `'gemini'`). | `GEMINI_API_KEY` | `""` |
| `model_name` | Name of the LLM model to use (e.g., `'gpt-4-1106-preview'` for OpenAI, `'gemini-1.5-flash'` for Gemini). **Required if `llm_provider` is `'gemini'`.** | `LLM_MODEL_NAME` | `'gpt-4-1106-preview'` |
| `temperature` | What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. | `GPT_TEMPERATURE` | `0.5` |
| `request_timeout` | Timeout for the request in seconds. | `GPT_REQUEST_TIMEOUT` | `30` |
| `master_locale` | Master language/locale for the source texts. | `MASTER_LOCALE` | `'en-US'` |
| `context` | Context for translation to improve accuracy. | `GPT_CONTEXT` | `nil` |
| `platform` | Platform for which to translate (`ios` or `android`). | `PLATFORM` | `'ios'` |

## Authentication

`translate-gpt-release-notes` supports authentication for both OpenAI and Google Gemini:

### OpenAI

#### API Key Parameter
You can provide your OpenAI API key directly using the `api_token` option:
```ruby
translate_gpt_release_notes(
  llm_provider: 'openai', # Default, can be omitted
  api_token: 'YOUR_OPENAI_API_KEY',
  # ... other options
)
```

#### Environment Variable
Alternatively, set the `GPT_API_KEY` environment variable:

```bash
export GPT_API_KEY='YOUR_OPENAI_API_KEY'
```
Then call the action without the `api_token` parameter:
```ruby
translate_gpt_release_notes(
  # api_token will be picked up from ENV['GPT_API_KEY']
  # ... other options
)
```

### Google Gemini

#### API Key Parameter
Provide your Gemini API key directly using the `gemini_api_key` option:
```ruby
translate_gpt_release_notes(
  llm_provider: 'gemini',
  gemini_api_key: 'YOUR_GEMINI_API_KEY',
  model_name: 'gemini-1.5-flash', # Remember to specify model
  # ... other options
)
```

#### Environment Variable
Alternatively, set the `GEMINI_API_KEY` environment variable:
```bash
export GEMINI_API_KEY='YOUR_GEMINI_API_KEY'
```
Then call the action without the `gemini_api_key` parameter:
```ruby
translate_gpt_release_notes(
  llm_provider: 'gemini',
  # gemini_api_key will be picked up from ENV['GEMINI_API_KEY']
  model_name: 'gemini-1.5-flash', # Remember to specify model
  # ... other options
)
```

## Important notes:

1. **Android Character Limit:** Android has a limit of 500 characters for changelogs. While the plugin attempts to manage this by instructing the LLM, translations (especially from concise languages) might still exceed this limit, potentially causing errors during app submission. Reducing the length of the `master_locale` changelog can help mitigate this. iOS has a much larger limit (4000 characters).
2. **API Costs:** Using either OpenAI or Google Gemini APIs incurs costs based on usage. Be mindful of the pricing models for the selected provider and model.
3. **Model Selection:** When using `llm_provider: 'gemini'`, you **must** specify a valid Gemini model name using the `model_name` parameter (e.g., `'gemini-1.5-flash'`, `'gemini-1.5-pro'`). The default `model_name` only applies when using OpenAI.

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
