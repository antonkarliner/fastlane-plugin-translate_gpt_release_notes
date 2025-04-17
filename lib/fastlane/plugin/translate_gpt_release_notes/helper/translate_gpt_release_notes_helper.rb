# frozen_string_literal: true

require 'fastlane_core/ui/ui'
require 'openai'
require 'gemini-ai' # Using gemini-ai gem
require 'json'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class TranslateGptReleaseNotesHelper
      def initialize(params)
        @params = params
        @provider = params[:llm_provider]

        case @provider
        when 'openai'
          unless params[:api_token] && !params[:api_token].empty?
            UI.user_error!("OpenAI API token (api_token or GPT_API_KEY) is required when using the 'openai' provider.")
          end
          @client = OpenAI::Client.new(
            access_token: params[:api_token],
            request_timeout: params[:request_timeout]
          )
        when 'gemini'
          unless params[:gemini_api_key] && !params[:gemini_api_key].empty?
            UI.user_error!("Gemini API key (gemini_api_key or GEMINI_API_KEY) is required when using the 'gemini' provider.")
          end
          # Initialize the gemini-ai client
          # Assuming it takes credentials and server options similar to the search result examples
          @client = Gemini.new(
            credentials: { service: 'generative-language-api', api_key: params[:gemini_api_key] },
            options: { model: params[:model_name], server: 'generativelanguage.googleapis.com' } # Pass model here? Check gem docs. Timeout might be an option too.
          )
          # Note: Timeout handling might need adjustment based on gem's specific options. Using request_timeout from params.
          @client.options[:timeout] = params[:request_timeout] if params[:request_timeout]
        else
          # This case should be caught by the verify_block in the action
          UI.user_error!("Invalid LLM provider specified: #{@provider}")
        end
      end

      # Request a translation from the selected LLM API
      def translate_text(text, target_locale, platform)
        source_locale = @params[:master_locale]
        model_name = @params[:model_name] # Used by both providers now
        temperature = @params[:temperature] || 0.5

        # --- Prompt Construction (Common Logic) ---
        prompt_text = "Translate this text from #{source_locale} to #{target_locale}:\n#{text}"


        if platform == 'android'
          prompt_text += "\n\nNote: The length of the translated text should be 500 symbols maximum. Rephrase a little if needed."
        end

        if @params[:context] && !@params[:context].empty?
          prompt_text = "Context: #{@params[:context]}\n" + prompt_text
        end
        # --- End Prompt Construction ---

        begin
          case @provider
          when 'openai'
            # --- OpenAI API Call ---
            UI.message("Requesting translation from OpenAI (#{model_name})...")
            response = @client.chat(
              parameters: {
                model: model_name, # Use the provided model name
                messages: [{ role: "user", content: prompt_text }],
                temperature: temperature
              }
            )

            error = response.dig("error", "message")
            if error
              UI.error "Error translating text with OpenAI: #{error}"
              return nil
            else
              translated_text = response.dig("choices", 0, "message", "content")&.strip
              if translated_text
                UI.message "Translated text (OpenAI): #{translated_text}"
                return translated_text
              else
                UI.error "Failed to parse translation from OpenAI response: #{response}"
                return nil
              end
            end
            # --- End OpenAI API Call ---

          when 'gemini'
            # --- Gemini API Call (using gemini-ai gem) ---
            # Ensure a model name is provided for Gemini
            unless model_name && !model_name.empty?
              UI.user_error!("Model name (model_name or LLM_MODEL_NAME) is required when using the 'gemini' provider.")
            end
            # Update client model if it wasn't set during init or needs changing per call
            @client.options[:model] = model_name

            UI.message("Requesting translation from Google Gemini (#{model_name} via gemini-ai)...")

            # Construct the request payload for gemini-ai (structure might differ slightly)
            # Assuming generate_content method exists and takes a simple hash or specific objects
            # Based on common patterns, it might take a prompt string directly or a structured input.
            # Let's assume a simple prompt string for now.
            # We also need to pass generation config like temperature.
            request_payload = {
              prompt: prompt_text,
              temperature: temperature
              # Add other parameters like max_tokens if supported by the gem
            }

            # Execute the request using the gemini-ai client method (e.g., generate_content)
            # The exact method name and response structure need confirmation from gem documentation
            response = @client.generate_content(request_payload) # Adjust method/params as needed

            # Check for errors and parse the response (adapt based on gemini-ai's response format)
            # Assuming response might be a hash or object with 'text' or 'candidates'
            if response.is_a?(Hash) && response['error']
              UI.error "Error translating text with Gemini (gemini-ai): #{response['error']['message']}"
              return nil
            elsif response.respond_to?(:text) && !response.text.empty? # Simple text response?
              translated_text = response.text.strip
              UI.message "Translated text (Gemini): #{translated_text}"
              return translated_text
            elsif response.respond_to?(:candidates) && !response.candidates.empty? # OpenAI-like structure?
              # Adapt parsing based on actual structure
              translated_text = response.candidates.first&.content&.parts&.map(&:text)&.join&.strip
              if translated_text
                UI.message "Translated text (Gemini): #{translated_text}"
                return translated_text
              else
                UI.error "Failed to parse translation from Gemini (gemini-ai) response: #{response.inspect}"
                return nil
              end
            else
              # Fallback error if response format is unexpected
              UI.error "Unexpected response format from Gemini (gemini-ai): #{response.inspect}"
              return nil
            end
            # --- End Gemini API Call ---
          end
        rescue StandardError => e
          # Catch potential network errors or other exceptions during API calls
          UI.error "An unexpected error occurred during translation with #{@provider}: #{e.message}"
          UI.error e.backtrace.join("\n") # Log backtrace for debugging
          return nil
        end
      end

      # Sleep for a specified number of seconds, displaying a progress bar (no changes needed)
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
