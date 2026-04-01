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
        # @param glossary_terms [Hash] Optional glossary { source_term => target_translation }
        # @return [String, nil] Translated text or nil on error
        def translate(text, source_locale, target_locale, glossary_terms: {})
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
        # Structure: instructions first, context/glossary in the middle, text to translate last.
        # This ordering ensures the model reads all constraints before processing the text.
        #
        # @param text [String] The text to translate
        # @param source_locale [String] Source language code
        # @param target_locale [String] Target language code
        # @param glossary_terms [Hash] Optional glossary { source_term => target_translation }
        # @return [String] The formatted prompt
        def build_prompt(text, source_locale, target_locale, glossary_terms: {}, platform: nil)
          prompt_parts = []

          # Instructions first: role, task, and output format
          prompt_parts << "Translate the following release notes from #{source_locale} to #{target_locale}."
          prompt_parts << "Respond with ONLY the translated text. Preserve the original formatting, line breaks, and bullet points."

          # Android character limit is a hard constraint — include it with core instructions
          if platform == 'android'
            prompt_parts << ""
            prompt_parts << android_limitation_instruction
          end

          # Add context if provided
          if @params[:context]
            prompt_parts << ""
            prompt_parts << "Context: #{@params[:context]}"
          end

          # Add glossary terms before the text so the model reads them first
          unless glossary_terms.nil? || glossary_terms.empty?
            prompt_parts << ""
            prompt_parts << "Use the following glossary for consistent terminology. These are reference translations — apply appropriate grammatical forms (declension, conjugation, agreement) as needed for natural-sounding language in the target language. Do not copy verbatim if grammar requires a different form:"
            glossary_terms.each do |source_term, target_term|
              prompt_parts << "- \"#{source_term}\" -> \"#{target_term}\""
            end
          end

          # Text to translate last, so the model processes it with full context
          prompt_parts << ""
          prompt_parts << "Text to translate:"
          prompt_parts << text

          prompt_parts.join("\n")
        end

        # Builds a system instruction for providers that support separate system/user messages.
        # Contains all translation rules, context, and glossary — but NOT the text to translate.
        # Used by OpenAI (system message). Other providers use build_prompt which combines everything.
        #
        # @param source_locale [String] Source language code
        # @param target_locale [String] Target language code
        # @param glossary_terms [Hash] Optional glossary { source_term => target_translation }
        # @return [String] The system instruction
        def build_system_instruction(source_locale, target_locale, glossary_terms: {}, platform: nil)
          parts = []

          parts << "Translate the following release notes from #{source_locale} to #{target_locale}."
          parts << "Respond with ONLY the translated text. Preserve the original formatting, line breaks, and bullet points."

          # Android character limit is a hard constraint — include it with core instructions
          if platform == 'android'
            parts << ""
            parts << android_limitation_instruction
          end

          if @params[:context]
            parts << ""
            parts << "Context: #{@params[:context]}"
          end

          unless glossary_terms.nil? || glossary_terms.empty?
            parts << ""
            parts << "Use the following glossary for consistent terminology. These are reference translations — apply appropriate grammatical forms (declension, conjugation, agreement) as needed for natural-sounding language in the target language. Do not copy verbatim if grammar requires a different form:"
            glossary_terms.each do |source_term, target_term|
              parts << "- \"#{source_term}\" -> \"#{target_term}\""
            end
          end

          parts.join("\n")
        end

        # Returns the Android character limitation instruction as a standalone string.
        # Used by providers that build messages separately (e.g., OpenAI with system/user split).
        #
        # @return [String] The Android limitation instruction
        def android_limitation_instruction
          "CRITICAL: Google Play Store enforces a hard #{ANDROID_CHAR_LIMIT}-character limit for release notes. " \
          "Your translation MUST be #{ANDROID_CHAR_LIMIT} characters or fewer. " \
          "Count carefully and shorten or summarize if needed to stay within this limit."
        end

        # Truncates the translated text to the Android character limit if exceeded.
        # Logs a warning when truncation occurs.
        #
        # @param text [String, nil] The translated text
        # @return [String, nil] The text, truncated to ANDROID_CHAR_LIMIT if necessary
        def enforce_android_limit(text)
          return text unless @params[:platform] == 'android' && text && text.length > ANDROID_CHAR_LIMIT

          UI.warning("Translation exceeds #{ANDROID_CHAR_LIMIT} characters (#{text.length}), truncating...")
          text[0...ANDROID_CHAR_LIMIT]
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
