require 'fastlane_core/ui/ui'
require_relative 'providers/provider_factory'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class TranslateGptReleaseNotesHelper
      def initialize(params)
        @params = params
        provider_name = params[:provider] || 'openai'

        # Validate provider selection
        unless Providers::ProviderFactory.valid_provider?(provider_name)
          UI.warning "Unknown provider '#{provider_name}', falling back to OpenAI"
          provider_name = 'openai'
        end

        # Create provider via factory (handles credential resolution)
        @provider = Providers::ProviderFactory.create(provider_name, params)

        # Validate provider configuration
        unless @provider.valid?
          UI.user_error!("Provider configuration errors: #{@provider.config_errors.join(', ')}")
        end
      end

      # Request a translation from the configured provider
      def translate_text(text, target_locale, _platform)
        source_locale = @params[:master_locale]
        @provider.translate(text, source_locale, target_locale)
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
