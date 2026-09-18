require 'fastlane_core/ui/ui'
require_relative 'providers/provider_factory'
require_relative 'glossary_loader'
require_relative 'translation_evaluator'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class TranslateGptReleaseNotesHelper
      attr_reader :quality_checks

      def initialize(params)
        @params = params
        @quality_checks = {}
        @evaluator = TranslationEvaluator.new(params) if params[:jev_check]
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
      def translate_text(text, target_locale, platform)
        source_locale = @params[:master_locale]
        glossary_terms = @glossary_loader&.terms_for(text, target_locale) || {}

        if glossary_terms.any?
          UI.message("Glossary: #{glossary_terms.size} terms matched for #{target_locale}")
        end

        translation = @provider.translate(text, source_locale, target_locale, glossary_terms: glossary_terms)
        if @evaluator && translation && !translation.to_s.strip.empty?
          result = @evaluator.evaluate(text, translation, source_locale, target_locale, glossary_terms: glossary_terms, platform: platform)
          @quality_checks[target_locale] = result
          report_quality_check(target_locale, result)
        end
        translation
      end

      private

      def report_quality_check(locale, result)
        if result[:status] == 'unavailable'
          UI.important("Jev #{locale}: check unavailable (#{result[:error]}); translation retained.")
        elsif result[:warnings].any?
          findings = result[:warnings].map { |name, probability| "#{name}=#{format('%.2f', probability)}" }.join(', ')
          UI.important("Jev #{locale}: quality warning — #{findings}. Translation retained.")
        else
          UI.message("Jev #{locale}: no quality warnings detected.")
        end
      end

    end
  end
end
