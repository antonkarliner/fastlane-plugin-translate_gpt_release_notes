module Fastlane
  module Helper
    module Providers
      # Abstract base class for all translation providers.
      # Subclasses must implement all abstract methods to provide
      # provider-specific translation functionality.
      class BaseProvider
        # Maximum character length for Google Play release notes
        ANDROID_CHAR_LIMIT = 500

        attr_reader :params, :config_errors

        # Initializes the provider with configuration parameters.
        # Automatically validates the configuration.
        #
        # @param params [Hash] Configuration parameters for the provider
        def initialize(params)
          @params = params
          @config_errors = []
          validate_config!
        end

        # Translates text from source locale to target locale.
        # Must be implemented by subclasses.
        #
        # @param text [String] The text to translate
        # @param source_locale [String] Source language code (e.g., 'en', 'de')
        # @param target_locale [String] Target language code (e.g., 'es', 'fr')
        # @return [String, nil] Translated text or nil on error
        def translate(text, source_locale, target_locale)
          raise NotImplementedError, "#{self.class.name} must implement #translate"
        end

        # Validates provider-specific configuration.
        # Should populate @config_errors with any validation failures.
        # Must be implemented by subclasses.
        #
        # @return [void]
        def validate_config!
          raise NotImplementedError, "#{self.class.name} must implement #validate_config!"
        end

        # Returns the provider identifier string.
        # Must be implemented by subclasses.
        #
        # @return [String] Provider identifier (e.g., 'openai', 'anthropic')
        def self.provider_name
          raise NotImplementedError, "#{name} must implement .provider_name"
        end

        # Returns the human-readable display name for the provider.
        # Must be implemented by subclasses.
        #
        # @return [String] Human-readable name (e.g., 'OpenAI GPT', 'Anthropic Claude')
        def self.display_name
          raise NotImplementedError, "#{name} must implement .display_name"
        end

        # Returns the list of required credential symbols for this provider.
        # Must be implemented by subclasses.
        #
        # @return [Array<Symbol>] Array of required credential keys
        def self.required_credentials
          raise NotImplementedError, "#{name} must implement .required_credentials"
        end

        # Returns a hash of optional parameter definitions for this provider.
        # Keys are parameter names, values are hashes with :default and :description.
        # Must be implemented by subclasses.
        #
        # @return [Hash] Optional parameter definitions
        def self.optional_params
          raise NotImplementedError, "#{name} must implement .optional_params"
        end

        # Checks if the provider configuration is valid.
        #
        # @return [Boolean] true if no configuration errors exist
        def valid?
          @config_errors.empty?
        end

        protected

        # Builds a translation prompt for the AI provider.
        # Includes context about platform limitations if applicable.
        #
        # @param text [String] The text to translate
        # @param source_locale [String] Source language code
        # @param target_locale [String] Target language code
        # @return [String] The formatted prompt
        def build_prompt(text, source_locale, target_locale)
          prompt_parts = []

          # Base translation instruction
          prompt_parts << "Translate the following text from #{source_locale} to #{target_locale}:"
          prompt_parts << ""
          prompt_parts << "\"#{text}\""

          # Add context if provided
          if @params[:context]
            prompt_parts << ""
            prompt_parts << "Context: #{@params[:context]}"
          end

          # Apply Android limitations if specified
          if @params[:android_limitations]
            prompt_parts << ""
            prompt_parts << apply_android_limitations("")
          end

          prompt_parts.join("\n")
        end

        # Adds Android character limit constraint to the prompt.
        # Google Play has a 500 character limit for release notes.
        #
        # @param prompt [String] The existing prompt to append to
        # @return [String] The prompt with limitation instruction appended
        def apply_android_limitations(prompt)
          prompt + "IMPORTANT: The translated text must not exceed #{ANDROID_CHAR_LIMIT} characters " \
          "(Google Play Store release notes limit). Please provide a concise translation."
        end

        # Adds a configuration error to the errors list.
        #
        # @param message [String] The error message
        # @return [void]
        def add_config_error(message)
          @config_errors << message
          UI.error("[#{self.class.display_name}] #{message}") if defined?(UI)
        end

        # Retrieves a credential value from environment variables or params.
        # Checks environment variable first, then falls back to params.
        #
        # @param key [Symbol] The credential key
        # @return [String, nil] The credential value or nil if not found
        def credential(key)
          env_var = "TRANSLATE_#{self.class.provider_name.upcase}_#{key.to_s.upcase}"
          ENV[env_var] || @params[key]
        end

        # Checks if a required credential is present.
        # Adds a config error if the credential is missing.
        #
        # @param key [Symbol] The credential key to validate
        # @return [Boolean] true if the credential is present
        def require_credential(key)
          value = credential(key)
          if value.nil? || value.to_s.empty?
            add_config_error("Missing required credential: #{key}")
            false
          else
            true
          end
        end
      end
    end
  end
end
