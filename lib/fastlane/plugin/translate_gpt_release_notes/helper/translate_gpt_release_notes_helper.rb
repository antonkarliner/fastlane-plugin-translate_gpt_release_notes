require 'fastlane_core/ui/ui'
require_relative 'providers/provider_factory'
require_relative 'glossary_loader'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class TranslateGptReleaseNotesHelper
      def initialize(params)
        @params = params
        provider_name = params[:provider] || 'openai'

        # Validate provider selection
        unless Providers::ProviderFactory.valid_provider?(provider_name)
          UI.important "Unknown provider '#{provider_name}', falling back to OpenAI"
          provider_name = 'openai'
        end

        # Create provider via factory (handles credential resolution)
        @provider = Providers::ProviderFactory.create(provider_name, params)

        # Validate provider configuration
        unless @provider.valid?
          UI.user_error!("Provider configuration errors: #{@provider.config_errors.join(', ')}")
        end

        # Initialize glossary loader if glossary parameters are provided
        if params[:glossary] || params[:glossary_dir]
          @glossary_loader = GlossaryLoader.new(params)
          UI.message("Glossary sources: #{[params[:glossary] && 'file', params[:glossary_dir] && 'directory'].compact.join(' + ')}")
        end
      end

      # Request a translation from the configured provider
      def translate_text(text, target_locale, _platform)
        source_locale = @params[:master_locale]
        glossary_terms = @glossary_loader&.terms_for(text, target_locale) || {}

        if glossary_terms.any?
          UI.message("Glossary: #{glossary_terms.size} terms matched for #{target_locale}")
        end

        @provider.translate(text, source_locale, target_locale, glossary_terms: glossary_terms)
      end

    end
  end
end
