require 'fastlane/action'
require 'openai'
require_relative '../helper/translate_gpt_release_notes_helper'

module Fastlane
  module Actions
    class TranslateGptReleaseNotesAction < Action
      def self.run(params)
        # Determine if iOS or Android based on the platform
        is_ios = params[:platform] == 'ios'
        base_directory = is_ios ? 'fastlane/metadata' : 'fastlane/metadata/android'

        # Check if the base directory exists before proceeding
        unless Dir.exist?(base_directory)
          UI.error("Directory does not exist: #{base_directory}")
          return
        end

        locales = list_locales(base_directory)
        master_texts = fetch_master_texts(base_directory, params[:master_locale], is_ios)

        helper = Helper::TranslateGptReleaseNotesHelper.new(params)
        translated_texts = locales.each_with_object({}) do |locale, translations|
          next if locale == params[:master_locale]  # Skip master locale
          translations[locale] = helper.translate_text(master_texts, locale, params[:platform])
        end

        update_translated_texts(base_directory, translated_texts, is_ios, params)
      end

      def self.list_locales(base_directory)
        Dir.children(base_directory).select { |entry| File.directory?(File.join(base_directory, entry)) }
      end

      def self.fetch_master_texts(base_directory, master_locale, is_ios)
        master_path = is_ios ? File.join(base_directory, master_locale) : File.join(base_directory, master_locale, 'changelogs')
      
        # Check if the master path exists
        unless Dir.exist?(master_path)
          UI.error("Master path does not exist: #{master_path}")
          return nil
        end
      
        filename = is_ios ? 'release_notes.txt' : highest_numbered_file(master_path)
      
        # Check if the file exists before reading
        file_path = File.join(master_path, filename)
        unless File.exist?(file_path)
          UI.error("File does not exist: #{file_path}")
          return nil
        end
      
        File.read(file_path)
      end      

      def self.highest_numbered_file(directory)
        Dir[File.join(directory, '*.txt')].max_by { |f| File.basename(f, '.txt').to_i }.split('/').last
      end      

      def self.update_translated_texts(base_directory, translated_texts, is_ios, params)
        translated_texts.each do |locale, text|
          next if locale == params[:master_locale]  # Skip master locale
      
          target_path = is_ios ? File.join(base_directory, locale) : File.join(base_directory, locale, 'changelogs')
      
          # Ensure target path exists or create it
          FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)
      
          filename = is_ios ? 'release_notes.txt' : highest_numbered_file(File.join(base_directory, params[:master_locale], 'changelogs'))
      
          # Write the translated text to the file
          File.write(File.join(target_path, filename), text)
        end
      end
      

      def self.description
        "Translate release notes or changelogs for iOS and Android apps using OpenAI's GPT API"
      end

      def self.available_options
        [
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
            description: "Name of the ChatGPT model to use",
            default_value: "gpt-4-1106-preview"
          ),
          FastlaneCore::ConfigItem.new(
            key: :request_timeout,
            env_name: "GPT_REQUEST_TIMEOUT",
            description: "Timeout for the request in seconds",
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
          )
        ]
      end

      def self.output
        [
          ['LOCALES_TRANSLATED', 'List of locales to which translations were applied'],
          ['MASTER_LOCALE', 'The master language/locale used as the source for translations']
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