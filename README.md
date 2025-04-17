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

`translate-gpt-release-notes` is a fastlane plugin that allows you to translate release notes or changelogs for iOS and Android apps using OpenAI GPT API. Based on [translate-gpt by ftp27](https://github.com/ftp27/fastlane-plugin-translate_gpt).


## How it works:

`translate-gpt-release-notes` takes the changelog file for master locale (default: en-US), detects other locales based on fastlane metadata folder structure, translates changelog to all other languages with OpenAI API and creates localized .txt changelong files in respective folders

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

| Key | Description | Environment Variable |
| --- | --- | --- |
| `api_token` | The API key for your OpenAI GPT account. | `GPT_API_KEY` |
| `model_name` | Name of the ChatGPT model to use (default: gpt-4-1106-preview) | `GPT_MODEL_NAME` |
| `temperature` | What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. Defaults to 0.5 | `GPT_TEMPERATURE` |
| `request_timeout` | Timeout for the request in seconds. Defaults to 30 seconds | `GPT_REQUEST_TIMEOUT` |
| `master_locale` | Master language/locale for the source texts | `MASTER_LOCALE` |
| `context` | Context for translation to improve accuracy | `GPT_CONTEXT` |
| `platform` | Platform for which to translate (ios or android, defaults to ios).| `PLATFORM` |

## Authentication

`translate-gpt-release-notes` supports multiple authentication methods for the OpenAI GPT API:

### API Key

You can provide your API key directly as an option to `translate-gpt`:

```ruby
translate_gpt_release_notes(
  api_token: 'YOUR_API_KEY',
  master_locale: 'en-US',
  platform: 'ios',
  context: 'This is an app about cute kittens'

)
```

### Environment Variable

Alternatively, you can set the `GPT_API_KEY` environment variable with your API key:

```bash
export GPT_API_KEY='YOUR_API_KEY'
```

And then call `translate-gp-release-notes` without specifying an API key:

```ruby
translate_gpt_release_notes(
  master_locale: 'en-US',
  platform: 'ios',
  context: 'This is an app about cute kittens'
)
```
## Important notes:

1. Android has a limit of 500 symbols for changelogs and sometimes translations can exceed this number, which leads to Google API errors when submitting the app. Plugin **tries** to handle this, however errors happen. Reducing the length of master_locale changelog usually helps. iOS has a limit of 4000 symbols, which is plenty.
2. OpenAI API usage cost money, keep it in mind.

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
