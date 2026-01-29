module Fastlane
  module Helper
    # CredentialResolver manages multiple provider API keys simultaneously,
    # allowing users to configure keys for all providers and select which
    # to use via the provider parameter.
    #
    # This class provides a centralized way to resolve API credentials from
    # various sources (parameters, environment variables) with a defined
    # priority order.
    class CredentialResolver
      # Maps each provider to its credential configuration
      # Each provider has:
      # - env_vars: Array of environment variable names to check (in order)
      # - param_key: Symbol for the parameter key in the params hash
      PROVIDER_CREDENTIALS = {
        'openai' => {
          env_vars: ['OPENAI_API_KEY', 'GPT_API_KEY'],  # GPT_API_KEY for backward compatibility
          param_key: :openai_api_key
        },
        'anthropic' => {
          env_vars: ['ANTHROPIC_API_KEY'],
          param_key: :anthropic_api_key
        },
        'gemini' => {
          env_vars: ['GEMINI_API_KEY'],
          param_key: :gemini_api_key
        },
        'deepl' => {
          env_vars: ['DEEPL_API_KEY'],
          param_key: :deepl_api_key
        }
      }.freeze

      # Resolves the API key for a given provider following priority order:
      # 1. Direct parameter (e.g., params[:openai_api_key])
      # 2. Environment variables in order defined in PROVIDER_CREDENTIALS
      # 3. Legacy fallback for OpenAI (GPT_API_KEY) if defined in env_vars
      #
      # @param provider_name [String] The provider identifier (e.g., 'openai', 'anthropic')
      # @param params [Hash] Hash of parameters that may contain API keys
      # @return [String, nil] The resolved API key or nil if not found
      def self.resolve(provider_name, params = {})
        config = provider_config(provider_name)
        return nil unless config

        # Priority 1: Check direct parameter
        param_value = params[config[:param_key]]
        return param_value.to_s.strip unless param_value.nil? || param_value.to_s.strip.empty?

        # Priority 2: Check environment variables in order
        config[:env_vars].each do |env_var|
          env_value = ENV[env_var]
          return env_value.to_s.strip unless env_value.nil? || env_value.to_s.strip.empty?
        end

        nil
      end

      # Checks if credentials exist for a given provider.
      #
      # @param provider_name [String] The provider identifier
      # @param params [Hash] Hash of parameters that may contain API keys
      # @return [Boolean] true if credentials exist, false otherwise
      def self.credentials_exist?(provider_name, params = {})
        !resolve(provider_name, params).nil?
      end

      # Returns an array of provider names that have configured credentials.
      #
      # @param params [Hash] Hash of parameters that may contain API keys
      # @return [Array<String>] Array of provider names with valid credentials
      def self.available_providers(params = {})
        PROVIDER_CREDENTIALS.keys.select do |provider_name|
          credentials_exist?(provider_name, params)
        end
      end

      # Returns help text explaining how to configure credentials for a provider.
      #
      # @param provider_name [String] The provider identifier
      # @return [String] Help text for configuring credentials
      def self.credential_help(provider_name)
        config = provider_config(provider_name)
        return "Unknown provider: #{provider_name}" unless config

        env_vars = config[:env_vars]
        param_key = config[:param_key]

        if env_vars.length == 1
          "Set #{env_vars.first} environment variable, or pass :#{param_key} parameter"
        else
          env_vars_str = env_vars.join(' or ')
          "Set #{env_vars_str} environment variable, or pass :#{param_key} parameter"
        end
      end

      # Returns an array of all supported provider names.
      #
      # @return [Array<String>] Array of all supported provider names
      def self.all_providers
        PROVIDER_CREDENTIALS.keys.freeze
      end

      private

      # Retrieves the credential configuration for a provider.
      # Handles case-insensitive provider names by downcasing.
      #
      # @param provider_name [String] The provider identifier
      # @return [Hash, nil] The credential configuration or nil if provider not found
      def self.provider_config(provider_name)
        return nil if provider_name.nil?

        PROVIDER_CREDENTIALS[provider_name.to_s.downcase]
      end
    end
  end
end
