require 'openai'
require_relative 'base_provider'

module Fastlane
  module Helper
    module Providers
      # Provider implementation for OpenAI GPT translation API.
      # Supports various GPT models including gpt-5.2 for translation tasks.
      class OpenAIProvider < BaseProvider
        # Default model for OpenAI translations
        DEFAULT_MODEL = 'gpt-5.2'.freeze

        # Default temperature for translation generation (0.5 = balanced creativity)
        DEFAULT_TEMPERATURE = 0.5

        # Default request timeout in seconds
        DEFAULT_TIMEOUT = 30

        # Returns the provider identifier string.
        #
        # @return [String] Provider identifier
        def self.provider_name
          'openai'
        end

        # Returns the human-readable display name for the provider.
        #
        # @return [String] Human-readable name
        def self.display_name
          'OpenAI GPT'
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
            model_name: { default: DEFAULT_MODEL, description: 'OpenAI model to use' },
            temperature: { default: DEFAULT_TEMPERATURE, description: 'Sampling temperature (0-2)' },
            service_tier: { default: nil, description: 'Service tier (e.g., "flex")' },
            request_timeout: { default: DEFAULT_TIMEOUT, description: 'Request timeout in seconds' }
          }
        end

        # Initializes the OpenAI provider with configuration parameters.
        # Sets up the OpenAI::Client with appropriate credentials and timeout.
        #
        # @param params [Hash] Configuration parameters for the provider
        def initialize(params)
          super

          timeout = normalized_timeout
          @client = OpenAI::Client.new(
            access_token: credential(:api_token),
            request_timeout: timeout
          )
        end

        # Validates the provider configuration.
        # Ensures that the required api_token credential is present.
        #
        # @return [void]
        def validate_config!
          require_credential(:api_token)
        end

        # Translates text from source locale to target locale using OpenAI's API.
        #
        # @param text [String] The text to translate
        # @param source_locale [String] Source language code (e.g., 'en', 'de')
        # @param target_locale [String] Target language code (e.g., 'es', 'fr')
        # @return [String, nil] Translated text or nil on error
        def translate(text, source_locale, target_locale)
          # Build prompt using inherited build_prompt method
          prompt = build_prompt(text, source_locale, target_locale)

          # Add Android limitations if needed
          prompt = apply_android_limitations(prompt) if @params[:platform] == 'android'

          # Build parameters hash
          parameters = {
            model: @params[:model_name] || DEFAULT_MODEL,
            messages: [{ role: 'user', content: prompt }],
            temperature: (@params[:temperature] || DEFAULT_TEMPERATURE).to_f
          }

          # Add service_tier if present
          service_tier = @params[:service_tier].to_s.strip
          parameters[:service_tier] = service_tier unless service_tier.empty?

          # Make API call
          response = @client.chat(parameters: parameters)

          # Handle errors and extract text
          if (error = response.dig('error', 'message'))
            UI.error "OpenAI translation error: #{error}"
            nil
          else
            response.dig('choices', 0, 'message', 'content')&.strip
          end
        rescue StandardError => e
          UI.error "OpenAI provider error: #{e.message}"
          nil
        end

        private

        # Normalizes the request timeout value based on service tier.
        # Flex service tier requires a minimum timeout of 900 seconds.
        #
        # @return [Integer, nil] Normalized timeout value or nil
        def normalized_timeout
          service_tier = @params[:service_tier].to_s.strip
          raw_timeout = @params[:request_timeout]

          # Use default timeout if not specified
          timeout = raw_timeout.nil? ? DEFAULT_TIMEOUT : raw_timeout.to_i

          if service_tier == 'flex' && timeout > 0 && timeout < 900
            UI.message('Flex processing detected; increasing request_timeout to 900s.')
            return 900
          end

          timeout
        end
      end
    end
  end
end
