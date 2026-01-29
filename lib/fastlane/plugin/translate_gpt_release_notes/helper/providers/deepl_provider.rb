require 'deepl'
require_relative 'base_provider'

module Fastlane
  module Helper
    module Providers
      # Provider implementation for DeepL translation API.
      # DeepL is a purpose-built neural machine translation service (not an LLM)
      # known for high-quality European language translations.
      class DeepLProvider < BaseProvider
        # Default request timeout in seconds
        DEFAULT_TIMEOUT = 30

        # Returns the provider identifier string.
        #
        # @return [String] Provider identifier
        def self.provider_name
          'deepl'
        end

        # Returns the human-readable display name for the provider.
        #
        # @return [String] Human-readable name
        def self.display_name
          'DeepL'
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
            request_timeout: {
              default: DEFAULT_TIMEOUT,
              env: 'DEEPL_REQUEST_TIMEOUT',
              description: 'Request timeout in seconds'
            },
            formality: {
              default: 'default',
              env: 'DEEPL_FORMALITY',
              description: 'Formality level: default, more, or less'
            }
          }
        end

        # Free DeepL API keys end with ':fx' and use a different endpoint
        FREE_KEY_SUFFIX = ':fx'.freeze

        # API endpoints for different key types
        API_HOST_PAID = 'https://api.deepl.com'.freeze
        API_HOST_FREE = 'https://api-free.deepl.com'.freeze

        # Initializes the DeepL provider with configuration parameters.
        # Configures the DeepL gem with the API authentication key.
        # Automatically detects free vs paid keys and uses the appropriate endpoint.
        #
        # @param params [Hash] Configuration parameters for the provider
        def initialize(params)
          super(params)

          api_key = params[:api_token].to_s
          return if api_key.nil? || api_key.empty?

          host = api_key.end_with?(FREE_KEY_SUFFIX) ? API_HOST_FREE : API_HOST_PAID

          DeepL.configure do |config|
            config.auth_key = api_key
            config.host = host
          end
        end

        # Validates the provider configuration.
        # Ensures that the required api_token credential is present.
        #
        # @return [void]
        def validate_config!
          require_credential(:api_token)
        end

        # Translates text from source locale to target locale using DeepL's API.
        #
        # @param text [String] The text to translate
        # @param source_locale [String] Source language code (e.g., 'en-US', 'de-DE')
        # @param target_locale [String] Target language code (e.g., 'es', 'fr')
        # @return [String, nil] Translated text or nil on error
        def translate(text, source_locale, target_locale)
          # DeepL uses ISO 639-1 language codes (2-letter codes)
          # Convert locales like 'en-US' to 'EN'
          source_lang = normalize_locale(source_locale)
          target_lang = normalize_locale(target_locale)

          # Build options hash
          options = {}

          # Add formality if specified (not available for all languages)
          formality = @params[:formality].to_s.strip
          options[:formality] = formality unless formality.empty? || formality == 'default'

          # DeepL supports context parameter for better translations
          if @params[:context] && !@params[:context].empty?
            options[:context] = @params[:context]
          end

          # Make API call
          result = DeepL.translate(text, source_lang, target_lang, options)

          translated = result.text

          # Handle Android 500 character limit
          if @params[:platform] == 'android' && translated.length > 500
            UI.warning "DeepL translation exceeds 500 characters (#{translated.length}), truncating..."
            translated = translated[0...500]
          end

          translated
        rescue DeepL::Exceptions::RequestError => e
          UI.error "DeepL API error: #{e.message}"
          nil
        rescue StandardError => e
          UI.error "DeepL provider error: #{e.message}"
          nil
        end

        private

        # Normalizes locale codes for DeepL API.
        # DeepL uses 2-letter ISO 639-1 codes (e.g., 'EN', 'DE', 'FR').
        # Converts 'en-US' → 'EN', 'de-DE' → 'DE'.
        #
        # @param locale [String] The locale string to normalize
        # @return [String] The normalized 2-letter language code
        def normalize_locale(locale)
          locale.to_s.split('-').first.upcase
        end
      end
    end
  end
end
