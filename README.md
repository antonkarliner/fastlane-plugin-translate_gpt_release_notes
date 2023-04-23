![logo](images/logo.png)

# translate-gpt plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-translate_gpt)
[![Gem Version](https://badge.fury.io/rb/fastlane-plugin-translate_gpt.svg)](https://badge.fury.io/rb/fastlane-plugin-translate_gpt)

## Getting Started

This project is a [fastlane](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-translate_gpt`, add it to your project by running:

```bash
fastlane add_plugin translate_gpt
```

## About translate-gpt

`translate-gpt` is a fastlane plugin that allows you to easily translate your iOS app's strings using the OpenAI GPT API.


## Features

- Automatically detects the source language and translates to the desired target language.
- Can take contextual information, such as comments in your code, into account to improve translation accuracy.
- Can automatically skip strings that are already translated, improving performance and reducing costs.

## Example

The following example demonstrates how to use `translate-gpt` in a `Fastfile` to translate an app's strings from English to French:

```ruby
lane :translate_strings do
  translate_gpt(
    api_key: 'YOUR_API_KEY',
    target_language: 'fr'
  )
end
```

## Options

The following options are available for `translate-gpt`:

| Key | Description | Environment Variable |
| --- | --- | --- |
| `api_key` | The API key for your OpenAI GPT account. | `GPT_API_KEY` |
| `model_name` | Name of the ChatGPT model to use | `GPT_MODEL_NAME` |
| `temperature` | What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. Defaults to 0.5 | `GPT_TEMPERATURE` |
| `request_timeout` | Timeout for the request in seconds. Defaults to 30 seconds | `GPT_REQUEST_TIMEOUT` |
| `skip_translated` | Whether to skip strings that have already been translated. Defaults to `true`. | `GPT_SKIP_TRANSLATED` |
| `source_language` | The source language of the strings to be translated. Defaults to auto-detection. | `GPT_SOURCE_LANGUAGE` |
| `target_language` | The target language of the translated strings. Required. | `GPT_TARGET_LANGUAGE` |
| `source_file` | The path to the `Localizable.strings` file to be translated. Defaults to `./Resources/Localizable.strings`. | `GPT_SOURCE_FILE` |
| `target_file` | The path to the output file for the translated strings. Defaults to `./Resources/Localizable.strings.<target_language>`. | `GPT_TARGET_FILE` |

## Authentication

`translate-gpt` supports multiple authentication methods for the OpenAI GPT API:

### API Key

You can provide your API key directly as an option to `translate-gpt`:

```ruby
translate-gpt(
  api_key: 'YOUR_API_KEY',
  target_language: 'fr'
)
```

### Environment Variable

Alternatively, you can set the `GPT_API_KEY` environment variable with your API key:

```bash
export GPT_API_KEY='YOUR_API_KEY'
```

And then call `translate-gpt` without specifying an API key:

```ruby
translate-gpt(
  target_language: 'fr'
)
```

## Issues and Feedback

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide. For any other issues and feedback about this plugin, please submit it to this repository or contact the maintainers on [Twitter](https://twitter.com/ftp27host).

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).

## Contributing

If you'd like to contribute to this plugin, please fork the repository and make your changes. When you're ready, submit a pull request explaining your changes.

## License

This action is released under the [MIT License](LICENSE).
