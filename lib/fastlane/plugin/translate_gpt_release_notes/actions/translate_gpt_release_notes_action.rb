require 'fastlane/action'
require_relative '../helper/translate_gpt_release_notes_helper'
require_relative '../helper/credential_resolver'
require_relative '../helper/providers/provider_factory'
require 'fileutils'

module Fastlane
  module Actions
    module SharedValues
      JEV_TRANSLATION_CHECKS = :JEV_TRANSLATION_CHECKS
    end

    class TranslateGptReleaseNotesAction < Action
      def self.run(params)
        Actions.lane_context[SharedValues::JEV_TRANSLATION_CHECKS] = {}
        provider_name = params[:provider] || 'openai'

        unless Helper::CredentialResolver.credentials_exist?(provider_name, params)
          available = Helper::CredentialResolver.available_providers(params)
          if available.empty?
            UI.user_error!("No translation provider credentials configured. Set one of: OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, or DEEPL_API_KEY")
          else
            UI.user_error!("Provider '#{provider_name}' has no credentials. Available providers: #{available.join(', ')}")
          end
        end

        # Define the path for the last run time file
        last_run_file = "last_successful_run.txt"

        # Determine if iOS or Android based on the platform
        is_ios = params[:platform] == 'ios'
        base_directory = is_ios ? 'fastlane/metadata' : 'fastlane/metadata/android'

        # Check if the base directory exists before proceeding
        unless Dir.exist?(base_directory)
          UI.error("Directory does not exist: #{base_directory}")
          return
        end

        locales = list_locales(base_directory)
        master_texts, master_file_path = fetch_master_texts(base_directory, params[:master_locale], is_ios)

        # Skip translation if master texts are not found
        unless master_texts && master_file_path
          UI.message("Master file not found, skipping translation.")
          return
        end
        
        # Compare last modification time with the last run time
        if File.exist?(last_run_file) && File.exist?(master_file_path)
          last_run_time = File.read(last_run_file).to_i
          file_mod_time = File.mtime(master_file_path).to_i
          if file_mod_time <= last_run_time
            UI.message("No changes in source file detected, translation skipped.")
            return
          end
        end

        helper = Helper::TranslateGptReleaseNotesHelper.new(params)
        translated_texts = locales.each_with_object({}) do |locale, translations|
          next if locale == params[:master_locale]  # Skip master locale
          translations[locale] = helper.translate_text(master_texts, locale, params[:platform])
        end
        Actions.lane_context[SharedValues::JEV_TRANSLATION_CHECKS] = helper.quality_checks

        if params[:dry_run]
          print_dry_run_preview(translated_texts, params)
        else
          update_translated_texts(base_directory, translated_texts, is_ios, params)

          # Only mark the run successful if at least one translation actually succeeded;
          # otherwise a transient failure would suppress the next run's retry.
          any_success = translated_texts.any? do |locale, text|
            locale != params[:master_locale] && !translation_empty?(text)
          end
          if any_success
            File.write(last_run_file, Time.now.to_i)
          else
            UI.error("No translations succeeded; not updating #{last_run_file} so the next run will retry.")
          end
        end
      end

      def self.list_locales(base_directory)
        Dir.children(base_directory).select { |entry| File.directory?(File.join(base_directory, entry)) }
      end

      def self.fetch_master_texts(base_directory, master_locale, is_ios)
        master_path = is_ios ? File.join(base_directory, master_locale) : File.join(base_directory, master_locale, 'changelogs')
      
        # Check if the master path exists
        unless Dir.exist?(master_path)
          UI.error("Master path does not exist: #{master_path}")
          return [nil, nil]
        end
      
        filename = is_ios ? 'release_notes.txt' : highest_numbered_file(master_path)
        file_path = File.join(master_path, filename)
      
        # Check if the file exists before reading
        unless File.exist?(file_path)
          UI.error("File does not exist: #{file_path}")
          return [nil, nil]
        end
      
        [File.read(file_path), file_path]
      end
        

      def self.highest_numbered_file(directory)
        Dir[File.join(directory, '*.txt')].max_by { |f| File.basename(f, '.txt').to_i }.split('/').last
      end      

      def self.translation_empty?(text)
        text.nil? || text.to_s.strip.empty?
      end

      def self.print_dry_run_preview(translated_texts, params)
        android_limit = 500 # Google Play hard limit; see BaseProvider::ANDROID_CHAR_LIMIT
        UI.important('DRY RUN: no files will be written.')
        translated_texts.each do |locale, text|
          next if locale == params[:master_locale]

          print_locale_preview(locale, text, android_limit, params[:platform])
        end
      end

      def self.print_locale_preview(locale, text, android_limit, platform)
        if text.nil? || text.to_s.strip.empty?
          UI.important("  #{locale}: translation FAILED (would be skipped)")
          return
        end
        length = text.length
        over = platform == 'android' && length > android_limit
        suffix = over ? " — EXCEEDS #{android_limit}-char Android limit" : ''
        UI.message("  #{locale}: #{length} chars#{suffix}")
      end

      def self.update_translated_texts(base_directory, translated_texts, is_ios, params)
        translated_texts.each do |locale, text|
          next if locale == params[:master_locale]  # Skip master locale

          if translation_empty?(text)
            UI.important("Skipping #{locale}: translation failed or returned empty; existing file left unchanged.")
            next
          end

          target_path = is_ios ? File.join(base_directory, locale) : File.join(base_directory, locale, 'changelogs')

          # Ensure target path exists or create it
          FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)

          filename = is_ios ? 'release_notes.txt' : highest_numbered_file(File.join(base_directory, params[:master_locale], 'changelogs'))

          # Write the translated text to the file
          File.write(File.join(target_path, filename), text)
        end
      end

      def self.description
        "Translate release notes using AI providers: OpenAI, Claude, Gemini, or DeepL"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :provider,
            env_name: 'TRANSLATION_PROVIDER',
            description: "Translation provider to use (#{Helper::Providers::ProviderFactory.available_provider_names.join(', ')})",
            type: String,
            default_value: 'openai',
            verify_block: proc do |value|
              unless Helper::Providers::ProviderFactory.valid_provider?(value)
                available = Helper::Providers::ProviderFactory.available_provider_names.join(', ')
                UI.user_error!("Invalid provider '#{value}'. Available: #{available}")
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :openai_api_key,
            env_name: 'OPENAI_API_KEY',
            description: 'OpenAI API key (alternative to environment variable)',
            sensitive: true,
            code_gen_sensitive: true,
            optional: true,
            default_value: nil
          ),
          FastlaneCore::ConfigItem.new(
            key: :anthropic_api_key,
            env_name: 'ANTHROPIC_API_KEY',
            description: 'Anthropic API key (alternative to environment variable)',
            sensitive: true,
            code_gen_sensitive: true,
            optional: true,
            default_value: nil
          ),
          FastlaneCore::ConfigItem.new(
            key: :gemini_api_key,
            env_name: 'GEMINI_API_KEY',
            description: 'Google Gemini API key (alternative to environment variable)',
            sensitive: true,
            code_gen_sensitive: true,
            optional: true,
            default_value: nil
          ),
          FastlaneCore::ConfigItem.new(
            key: :deepl_api_key,
            env_name: 'DEEPL_API_KEY',
            description: 'DeepL API key (alternative to environment variable)',
            sensitive: true,
            code_gen_sensitive: true,
            optional: true,
            default_value: nil
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_token,
            env_name: "GPT_API_KEY",
            description: "API token for ChatGPT",
            sensitive: true,
            code_gen_sensitive: true,
            default_value: ""
          ),
          FastlaneCore::ConfigItem.new(
            key: :model_name,
            env_name: "GPT_MODEL_NAME",
            description: "Name of the AI model to use (provider-specific)",
            default_value: "gpt-5.2"
          ),
          FastlaneCore::ConfigItem.new(
            key: :service_tier,
            env_name: "GPT_SERVICE_TIER",
            description: "OpenAI service tier to use (auto, default, flex, or priority)",
            type: String,
            optional: true,
            verify_block: proc do |value|
              next if value.nil? || value.to_s.strip.empty?
              allowed_values = %w[auto default flex priority]
              unless allowed_values.include?(value)
                UI.user_error!("Invalid service_tier '#{value}'. Allowed values: #{allowed_values.join(', ')}")
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :request_timeout,
            env_name: "GPT_REQUEST_TIMEOUT",
            description: "Timeout for the request in seconds (auto-bumped to 900s for flex if lower)",
            type: Integer,
            default_value: 30
          ),
          FastlaneCore::ConfigItem.new(
            key: :temperature,
            env_name: "GPT_TEMPERATURE",
            description: "What sampling temperature to use, between 0 and 2",
            type: Float,
            optional: true,
            default_value: 0.5
          ),
          FastlaneCore::ConfigItem.new(
            key: :master_locale,
            env_name: "MASTER_LOCALE",
            description: "Master language/locale for the source texts",
            type: String,
            default_value: "en-US"
          ),
          FastlaneCore::ConfigItem.new(
            key: :platform,
            env_name: "PLATFORM",
            description: "Platform for which to translate (ios or android)",
            is_string: true, 
            default_value: 'ios'
          ),
          FastlaneCore::ConfigItem.new(
            key: :context,
            env_name: "GPT_CONTEXT",
            description: "Context for translation to improve accuracy",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :glossary,
            env_name: "GLOSSARY_PATH",
            description: "Path to a JSON glossary file with term translations per locale",
            optional: true,
            type: String,
            verify_block: proc do |value|
              next if value.nil? || value.to_s.strip.empty?
              UI.user_error!("Glossary file not found: #{value}") unless File.exist?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :glossary_dir,
            env_name: "GLOSSARY_DIR",
            description: "Path to directory with localization files (ARB, .strings, .xml, .json, .xliff) for auto-extracting glossary",
            optional: true,
            type: String,
            verify_block: proc do |value|
              next if value.nil? || value.to_s.strip.empty?
              UI.user_error!("Glossary directory not found: #{value}") unless Dir.exist?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :jev_check,
            env_name: 'TRANSLATE_JEV_CHECK',
            description: 'Report optional Jev translation quality warnings without blocking writes',
            type: Boolean,
            optional: true,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :android_length_retries,
            env_name: 'TRANSLATE_ANDROID_LENGTH_RETRIES',
            description: 'Extra shortening attempts for oversized Android translations (OpenAI, Anthropic, Gemini; 0 to 2)',
            type: Integer,
            optional: true,
            default_value: 0,
            verify_block: proc do |value|
              UI.user_error!('android_length_retries must be between 0 and 2') unless value.between?(0, 2)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :typesafe_api_key,
            env_name: 'TYPESAFE_API_KEY',
            description: 'TypeSafe API key for optional Jev quality checks',
            type: String,
            sensitive: true,
            code_gen_sensitive: true,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :jev_model,
            env_name: 'TRANSLATE_JEV_MODEL',
            description: 'Jev model for translation quality checks',
            type: String,
            optional: true,
            default_value: Helper::TranslationEvaluator::DEFAULT_MODEL
          ),
          FastlaneCore::ConfigItem.new(
            key: :jev_threshold,
            env_name: 'TRANSLATE_JEV_THRESHOLD',
            description: 'Defect probability at or above which Jev reports a warning (0 to 1)',
            type: Float,
            optional: true,
            default_value: 0.5,
            verify_block: proc do |value|
              UI.user_error!('jev_threshold must be between 0 and 1') unless value.finite? && value.between?(0, 1)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :jev_timeout,
            env_name: 'TRANSLATE_JEV_TIMEOUT',
            description: 'Jev timeout in seconds per connection/read/write operation',
            type: Integer,
            optional: true,
            default_value: 10,
            verify_block: proc do |value|
              UI.user_error!('jev_timeout must be positive') unless value > 0
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :dry_run,
            env_name: 'TRANSLATE_DRY_RUN',
            description: 'Preview translations without writing files',
            type: Boolean,
            optional: true,
            default_value: false
          )
        ]
      end

      def self.output
        [
          ['LOCALES_TRANSLATED', 'List of locales to which translations were applied'],
          ['MASTER_LOCALE', 'The master language/locale used as the source for translations'],
          ['JEV_TRANSLATION_CHECKS', 'Per-locale Jev probabilities, warnings, and checker availability']
        ]
      end

      def self.return_value
        nil
      end      

      def self.authors
        ["antonkarliner"]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end      
    end
  end
end
