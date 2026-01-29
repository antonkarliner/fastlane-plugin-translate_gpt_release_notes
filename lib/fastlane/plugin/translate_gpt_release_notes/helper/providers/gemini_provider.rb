require 'net/http'
require 'json'
require_relative 'base_provider'

module Fastlane
  module Helper
    module Providers
      # Provider implementation for Google Gemini translation API using direct HTTP calls.
      # Offers cost-effective translations suitable for high-volume use cases.
      class GeminiProvider < BaseProvider
        # Default model for Gemini translations
        DEFAULT_MODEL = 'gemini-2.5-flash'.freeze

        # Default temperature for translation generation (0.5 = balanced creativity)
        DEFAULT_TEMPERATURE = 0.5

        # Default request timeout in seconds
        DEFAULT_TIMEOUT = 60

        # Base URL for Gemini Generative Language API
        API_BASE_URL = 'https://generativelanguage.googleapis.com'.freeze

        # Returns the provider identifier string.
        #
        # @return [String] Provider identifier
        def self.provider_name
          'gemini'
        end

        # Returns the human-readable display name for the provider.
        #
        # @return [String] Human-readable name
        def self.display_name
          'Google Gemini'
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
            model_name: { default: DEFAULT_MODEL, description: 'Gemini model to use', env: 'GEMINI_MODEL_NAME' },
            temperature: { default: DEFAULT_TEMPERATURE, description: 'Sampling temperature (0-1)', env: 'GEMINI_TEMPERATURE' },
            request_timeout: { default: DEFAULT_TIMEOUT, description: 'Request timeout in seconds', env: 'GEMINI_REQUEST_TIMEOUT' }
          }
        end

        # Initializes the Gemini provider with configuration parameters.
        #
        # @param params [Hash] Configuration parameters for the provider
        def initialize(params)
          super
          @api_key = params[:api_token]
          @model = @params[:model_name] || DEFAULT_MODEL
          @temperature = (@params[:temperature] || DEFAULT_TEMPERATURE).to_f
          @timeout = (@params[:request_timeout] || DEFAULT_TIMEOUT).to_i
        end

        # Validates the provider configuration.
        # Ensures that the required api_token credential is present.
        #
        # @return [void]
        def validate_config!
          require_credential(:api_token)
        end

        # Translates text from source locale to target locale using Gemini's API.
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

          # Make API call
          result = make_api_request(prompt)

          # Extract text from response
          extract_text_from_response(result)
        rescue StandardError => e
          UI.error "Gemini provider error: #{e.message}"
          nil
        end

        private

        # Makes the HTTP API request to Gemini.
        #
        # @param prompt [String] The prompt to send
        # @return [Hash] The parsed JSON response
        def make_api_request(prompt)
          uri = URI("#{API_BASE_URL}/v1beta/models/#{@model}:generateContent")
          uri.query = URI.encode_www_form(key: @api_key)

          request_body = {
            contents: [{
              role: 'user',
              parts: { text: prompt }
            }],
            generationConfig: {
              temperature: @temperature
            }
          }

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.read_timeout = @timeout

          request = Net::HTTP::Post.new(uri.request_uri)
          request['Content-Type'] = 'application/json'
          request.body = request_body.to_json

          response = http.request(request)

          unless response.is_a?(Net::HTTPSuccess)
            raise "API request failed: #{response.code} - #{response.message}"
          end

          JSON.parse(response.body)
        end

        # Extracts the translated text from the API response.
        #
        # @param response [Hash] The parsed JSON response
        # @return [String, nil] The translated text or nil
        def extract_text_from_response(response)
          candidates = response['candidates']
          return nil if candidates.nil? || candidates.empty?

          content = candidates.dig(0, 'content')
          return nil if content.nil?

          parts = content['parts']
          return nil if parts.nil? || parts.empty?

          parts.dig(0, 'text')&.strip
        end
      end
    end
  end
end
