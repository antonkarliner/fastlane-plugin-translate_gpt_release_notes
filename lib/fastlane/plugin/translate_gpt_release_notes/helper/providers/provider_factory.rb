require_relative '../credential_resolver'
require_relative 'base_provider'
require_relative 'openai_provider'
require_relative 'anthropic_provider'
require_relative 'gemini_provider'
require_relative 'deepl_provider'

module Fastlane
  module Helper
    module Providers
      # ProviderFactory is the central component for creating provider instances.
      # It uses CredentialResolver to resolve API keys and instantiates the
      # appropriate provider based on the provider_name parameter.
      #
      # This class provides a unified interface for creating any supported provider
      # with automatic credential resolution and validation.
      #
      # @example Creating a provider with automatic credential resolution
      #   provider = ProviderFactory.create('openai', { model_name: 'gpt-5.2' })
      #
      # @example Creating a provider with explicit API key
      #   provider = ProviderFactory.create_with_key('openai', 'sk-...', { model_name: 'gpt-5.2' })
      #
      class ProviderFactory
        # Mapping of provider names to their respective provider classes.
        # Used to look up and instantiate the correct provider implementation.
        PROVIDERS = {
          OpenAIProvider.provider_name => OpenAIProvider,
          AnthropicProvider.provider_name => AnthropicProvider,
          GeminiProvider.provider_name => GeminiProvider,
          DeepLProvider.provider_name => DeepLProvider
        }.freeze

        # Default provider to use when none is specified.
        DEFAULT_PROVIDER = 'openai'.freeze

        # Creates a provider instance with automatic credential resolution.
        #
        # This method resolves the API key using CredentialResolver, merges it into
        # the params, and instantiates the appropriate provider class.
        #
        # @param provider_name [String, nil] The provider identifier (e.g., 'openai', 'anthropic').
        #   Defaults to DEFAULT_PROVIDER if nil or not provided.
        # @param params [Hash] Configuration parameters for the provider.
        #   May include provider-specific options and credential overrides.
        # @return [BaseProvider] An instance of the requested provider class.
        # @raise [FastlaneCore::Interface::FastlaneError] If the provider name is unknown
        #   or if no API key can be resolved.
        def self.create(provider_name, params)
          provider_name = provider_name.to_s.empty? ? DEFAULT_PROVIDER : provider_name.to_s.downcase
          provider_class = PROVIDERS[provider_name]

          unless provider_class
            UI.user_error!("Unknown provider '#{provider_name}'. Available: #{available_provider_names.join(', ')}")
            return nil
          end

          # Resolve API key
          api_key = CredentialResolver.resolve(provider_name, params)

          unless api_key
            UI.user_error!("No API key found for provider '#{provider_name}'. #{CredentialResolver.credential_help(provider_name)}")
            return nil
          end

          # Merge API key into params
          provider_params = params.merge(api_token: api_key)

          provider_class.new(provider_params)
        end

        # Creates a provider instance with an explicit API key.
        #
        # This method bypasses credential resolution and uses the provided API key
        # directly. Useful when the key is obtained from an external source or
        # when credential resolution is not desired.
        #
        # @param provider_name [String] The provider identifier (e.g., 'openai', 'anthropic').
        # @param api_key [String] The API key to use for authentication.
        # @param params [Hash] Optional configuration parameters for the provider.
        # @return [BaseProvider] An instance of the requested provider class.
        # @raise [FastlaneCore::Interface::FastlaneError] If the provider name is unknown.
        def self.create_with_key(provider_name, api_key, params = {})
          provider_name = provider_name.to_s.downcase
          provider_class = PROVIDERS[provider_name]

          unless provider_class
            UI.user_error!("Unknown provider '#{provider_name}'")
            return nil
          end

          provider_params = params.merge(api_token: api_key)
          provider_class.new(provider_params)
        end

        # Returns an array of all available provider names.
        #
        # @return [Array<String>] Array of provider identifiers.
        def self.available_provider_names
          PROVIDERS.keys.freeze
        end

        # Returns a hash mapping provider names to their display names.
        #
        # @return [Hash<String, String>] Hash with provider names as keys and
        #   human-readable display names as values.
        def self.provider_display_names
          PROVIDERS.transform_values(&:display_name)
        end

        # Checks if a provider name is valid.
        #
        # @param provider_name [String] The provider identifier to check.
        # @return [Boolean] true if the provider is supported, false otherwise.
        def self.valid_provider?(provider_name)
          PROVIDERS.key?(provider_name.to_s.downcase)
        end

        # Gets the full configuration for a provider.
        #
        # Returns a comprehensive hash containing all configuration details
        # for the specified provider, including name, display name, required
        # credentials, optional parameters, and credential help text.
        #
        # @param provider_name [String] The provider identifier.
        # @return [Hash] Provider configuration hash with keys:
        #   - :name [String] Provider identifier
        #   - :display_name [String] Human-readable name
        #   - :required_credentials [Array<Symbol>] Required credential symbols
        #   - :optional_params [Hash] Optional parameter definitions
        #   - :credential_help [String] Help text for configuring credentials
        # @return [Hash] Empty hash if provider is not found.
        def self.provider_config(provider_name)
          provider_class = PROVIDERS[provider_name.to_s.downcase]
          return {} unless provider_class

          {
            name: provider_class.provider_name,
            display_name: provider_class.display_name,
            required_credentials: provider_class.required_credentials,
            optional_params: provider_class.optional_params,
            credential_help: CredentialResolver.credential_help(provider_name)
          }
        end
      end
    end
  end
end
