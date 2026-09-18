require 'net/http'
require 'json'

module Fastlane
  module Helper
    # Optional reporting-only checks. Evaluation failures never discard a translation.
    class TranslationEvaluator
      ENDPOINT = 'https://api.typesafe.ai/v1/systemone'.freeze
      DEFAULT_MODEL = 'jev-1.13.0'.freeze
      QUESTIONS = {
        'added_claim' => 'Does `translation` assert a feature, behavior, benefit, or fix not supported by `source`? Compare meaning across languages. Natural paraphrases and grammatical variants are not added claims. A direct reversal belongs to contradiction, not this check.',
        'omission' => 'Does `translation` omit an entire material feature, fix, benefit, or availability statement from `source`? Concise paraphrases and summaries are allowed under `policy`; preserving all material points in fewer words is not an omission. Direct contradictions belong to the contradiction check.',
        'contradiction' => 'Does `translation` make a statement with meaning directly contradicting `source`, such as reversing availability or saying a feature was removed when it was added? Compare meaning across languages.',
        'wrong_language' => 'Is the prose in `translation` in a language other than the language specified by `target_locale`, or are full source-language sentences left untranslated? Product names and short technical terms are exempt.',
        'glossary_error' => 'Does `translation` use a different UI feature name for a source term in `glossary` instead of the designated localized name? Allow capitalization, grammatical inflection, case endings, and agreement. Judge UI-name identity, not exact substring equality. If the term was omitted entirely, do not flag this check.'
      }.freeze

      def initialize(params)
        @api_key = params[:typesafe_api_key].to_s.strip
        @api_key = ENV['TYPESAFE_API_KEY'].to_s.strip if @api_key.empty?
        @model = params[:jev_model] || DEFAULT_MODEL
        @threshold = params[:jev_threshold] || 0.5
        @timeout = params[:jev_timeout] || 10
      end

      def evaluate(source, translation, source_locale, target_locale, glossary_terms: {}, platform: nil)
        return unavailable('TYPESAFE_API_KEY is not configured') if @api_key.to_s.strip.empty?

        state = {
          source: source, translation: translation, source_locale: source_locale,
          target_locale: target_locale, glossary: glossary_terms, platform: platform,
          policy: platform == 'android' ?
            'Android requires at most 500 characters. Summarize concisely and omit minor wording, while retaining every material feature, fix, and availability claim.' :
            'Preserve every material claim. Natural paraphrase and grammatical inflection are allowed.'
        }
        payload = {
          model: @model, state: state,
          questions: QUESTIONS.transform_values { |instructions| { type: 'noul', instructions: instructions } }
        }
        response = request(payload)
        return unavailable("HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

        parse_result(JSON.parse(response.body))
      rescue StandardError => e
        # Exception messages and API bodies can contain credentials or source text.
        unavailable("request failed (#{e.class})")
      end

      private

      def request(payload)
        uri = URI(ENDPOINT)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = @timeout
        http.read_timeout = @timeout
        http.write_timeout = @timeout
        request = Net::HTTP::Post.new(uri.request_uri)
        request['Authorization'] = "Bearer #{@api_key}"
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(payload)

        # Bound retries and delay so a checker outage does not stall a release lane.
        response = nil
        3.times do |attempt|
          response = http.request(request)
          break unless %w[429 529].include?(response.code) && attempt < 2

          delay = response['Retry-After'].to_f
          delay = 0.5 * (2**attempt) if delay <= 0
          # Respect a longer server delay by ending this optional check instead.
          break if delay > 2.0

          sleep(delay)
        end
        response
      end

      def parse_result(result)
        return unavailable('invalid response') unless result.is_a?(Hash) && result['model'].is_a?(String) && !result['model'].empty?

        answers = result['answers']
        return unavailable('invalid response') unless answers.is_a?(Hash)

        probabilities = {}
        QUESTIONS.each_key do |name|
          answer = answers[name]
          value = answer['noul'] if answer.is_a?(Hash)
          unless answer.is_a?(Hash) && answer['type'] == 'noul' && value.is_a?(Numeric) && value.finite? && value.between?(0, 1)
            return unavailable('invalid response')
          end
          probabilities[name] = value
        end
        {
          status: 'checked', model: result['model'], probabilities: probabilities,
          warnings: probabilities.select { |_name, probability| probability >= @threshold }
        }
      end

      def unavailable(reason)
        { status: 'unavailable', error: reason }
      end
    end
  end
end
