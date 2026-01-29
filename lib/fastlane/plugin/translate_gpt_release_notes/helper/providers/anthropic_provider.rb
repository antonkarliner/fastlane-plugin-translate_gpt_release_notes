require 'anthropic'
require_relative 'base_provider'

module Fastlane
  module Helper
    module Providers
      # Provider implementation for Anthropic Claude translation API.
      # Uses the Claude models for high-quality text translation with strong reasoning capabilities.
      class AnthropicProvider < BaseProvider
        # Default model for Anthropic translations
        DEFAULT_MODEL = 'claude-sonnet-4.5'.freeze

        # Default maximum tokens for translation response
        DEFAULT_MAX_TOKENS = 1024

        # Default temperature for translation generation (0.5 = balanced creativity)
        DEFAULT_TEMPERATURE = 0.5

        # Default request timeout in seconds
        DEFAULT_TIMEOUT = 60

        # Returns the provider identifier string.
        #
        # @return [String] Provider identifier
        def self.provider_name
          'anthropic'
        end

        # Returns the human-readable display name for the provider.
        #
        # @return [String] Human-readable name
        def self.display_name
          'Anthropic Claude'
        end

        # Returns the list of required credential symbols for this provider.
        #
        # @return [Array<Symbol>] Array of required credential keys
        def self.required_credentials
          [:api_token]
        end

        # Returns a hash of optional parameter definitions for this provider.
        #
        # @return [Hash] Optional parameter definitions
        def self.optional_params
          {
            model_name: { default: DEFAULT_MODEL, description: 'Anthropic model to use', env: 'ANTHROPIC_MODEL_NAME' },
            max_tokens: { default: DEFAULT_MAX_TOKENS, description: 'Maximum tokens in response', env: 'ANTHROPIC_MAX_TOKENS' },
            temperature: { default: DEFAULT_TEMPERATURE, description: 'Sampling temperature (0-1)', env: 'ANTHROPIC_TEMPERATURE' },
            request_timeout: { default: DEFAULT_TIMEOUT, description: 'Request timeout in seconds', env: 'ANTHROPIC_REQUEST_TIMEOUT' }
          }
        end

        # Initializes the Anthropic provider with configuration parameters.
        # Sets up the Anthropic::Client with appropriate credentials and timeout.
        #
        # @param params [Hash] Configuration parameters for the provider
        def initialize(params)
          super

          timeout = @params[:request_timeout] || DEFAULT_TIMEOUT
          @client = Anthropic::Client.new(
            api_key: credential(:api_token),
            timeout: timeout.to_i
          )
        end

        # Validates the provider configuration.
        # Ensures that the required api_token credential is present.
        #
        # @return [void]
        def validate_config!
          require_credential(:api_token)
        end

        # Translates text from source locale to target locale using Anthropic's API.
        #
        # @param text [String] The text to translate
        # @param source_locale [String] Source language code (e.g., 'en', 'de')
        # @param target_locale [String] Target language code (e.g., 'es', 'fr')
        # @return [String, nil] Translated text or nil on error
        def translate(text, source_locale, target_locale)
          # Build prompt using inherited method
          prompt = build_prompt(text, source_locale, target_locale)

          # Add Android limitations if needed
          prompt = apply_android_limitations(prompt) if @params[:platform] == 'android'

          # Make API call using ruby-anthropic gem API
          response = @client.complete(
            model: @params[:model_name] || DEFAULT_MODEL,
            max_tokens_to_sample: (@params[:max_tokens] || DEFAULT_MAX_TOKENS).to_i,
            temperature: (@params[:temperature] || DEFAULT_TEMPERATURE).to_f,
            prompt: "\n\nHuman: #{prompt}\n\nAssistant:"
          )

          # Extract text from response
          extract_text_from_response(response)
        rescue StandardError => e
          UI.error "Anthropic provider error: #{e.message}"
          nil
        end

        private

        # Extracts translated text from the Anthropic API response
        #
        # @param response [Hash] The API response hash
        # @return [String, nil] The translated text or nil
        def extract_text_from_response(response)
          return nil if response.nil?

          response['completion']&.strip
        end
      end
    end
  end
end
