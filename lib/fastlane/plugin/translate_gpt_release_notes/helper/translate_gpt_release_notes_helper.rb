require 'fastlane_core/ui/ui'
require 'openai'
require 'json'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class TranslateGptReleaseNotesHelper
      def initialize(params)
        @params = params
        @client = OpenAI::Client.new(
          access_token: params[:api_token],
          request_timeout: params[:request_timeout]
        )
      end

      # Request a translation from the GPT API
      def translate_text(text, target_locale, platform)
        source_locale = @params[:master_locale]
        prompt = "Translate this text from #{source_locale} to #{target_locale}:\n#{text}"


        # Add condition for Android platform
        if platform == 'android'
          prompt += "\n\nNote: The length of the translated text should be 500 symbols maximum. Rephrase a little if needed."
        end

        # Context handling
        if @params[:context] && !@params[:context].empty?
          prompt = "Context: #{@params[:context]}\n" + prompt
        end

        # Updated API call with max_tokens
        response = @client.chat(
          parameters: {
            model: @params[:model_name] || 'gpt-4-1106-preview',
            messages: [{ role: "user", content: prompt }],
            temperature: @params[:temperature] || 0.5
          }
        )

      
        error = response.dig("error", "message")
        if error
          UI.error "Error translating text: #{error}"
          return nil
        else
          translated_text = response.dig("choices", 0, "message", "content").strip
          UI.message "Translated text: #{translated_text}"
          return translated_text
        end
      end
      
      # Sleep for a specified number of seconds, displaying a progress bar
      def wait(seconds = @params[:request_timeout])
        sleep_time = 0
        while sleep_time < seconds
          percent_complete = (sleep_time.to_f / seconds.to_f) * 100.0
          progress_bar_width = 20
          completed_width = (progress_bar_width * percent_complete / 100.0).round
          remaining_width = progress_bar_width - completed_width
          print "\rTimeout ["
          print Colorizer::code(:green)
          print "=" * completed_width
          print " " * remaining_width
          print Colorizer::code(:reset)
          print "]"
          print " %.2f%%" % percent_complete
          $stdout.flush
          sleep(1)
          sleep_time += 1
        end
        print "\r"
        $stdout.flush
      end
    end

    # Helper class for bash colors
    class Colorizer
      COLORS = {
        black:   30,
        red:     31,
        green:   32,
        yellow:  33,
        blue:    34,
        magenta: 35,
        cyan:    36,
        white:   37,
        reset:   0,
      }
    
      def self.colorize(text, color)
        color_code = COLORS[color.to_sym]
        "\e[#{color_code}m#{text}\e[0m"
      end
      def self.code(color)
        "\e[#{COLORS[color.to_sym]}m"
      end
    end
  end
end
