require 'json'
require 'nokogiri'
require 'loco_strings'
require 'set'

module Fastlane
  module Helper
    # Loads glossary terms from curated JSON files or localization directories.
    # Supports ARB, Apple .strings, Android strings.xml, JSON i18n, and XLIFF formats.
    # Filters terms by fuzzy matching against source text to keep prompts concise.
    class GlossaryLoader
      # Supported localization file extensions and their format identifiers
      FORMAT_EXTENSIONS = {
        '.arb' => :arb,
        '.strings' => :strings,
        '.xml' => :android_xml,
        '.json' => :json,
        '.xliff' => :xliff,
        '.xlf' => :xliff
      }.freeze

      # Minimum word length for individual word matching in fuzzy search
      MIN_WORD_LENGTH = 4

      # Maximum term length in characters. Longer terms are full sentences/paragraphs
      # and not useful as glossary entries for translation prompts.
      MAX_TERM_LENGTH = 80

      # Common English stopwords excluded from individual word matching.
      # These are too generic to be useful for glossary term matching and cause
      # excessive false positives with real-world localization files.
      STOPWORDS = Set.new(%w[
        about also back been come could does done each even from
        give goes gone good have here high into just keep know
        like long look made make many more most much must need
        only once open over part read real right same show side
        some such sure take than that them then they this time
        used very want well what when will with work your
      ]).freeze

      # @param params [Hash] Plugin parameters containing glossary config
      def initialize(params)
        @glossary = {}
        @source_locale = params[:master_locale] || 'en-US'

        load_from_file(params[:glossary]) if params[:glossary]
        load_from_directory(params[:glossary_dir]) if params[:glossary_dir]

        if @glossary.empty?
          UI.message("Glossary: No terms loaded")
        else
          UI.message("Glossary: Loaded #{@glossary.size} source terms")
        end
      end

      # Returns glossary terms relevant to the source text for a specific target locale.
      # Applies fuzzy matching to include only terms that appear in the source text.
      #
      # @param source_text [String] The release notes text being translated
      # @param target_locale [String] Target language code (e.g., 'fr', 'de-DE')
      # @return [Hash] Filtered hash of { source_term => target_translation }
      def terms_for(source_text, target_locale)
        canonical = canonicalize_locale(target_locale)
        language_only = canonical.split('-').first
        result = {}

        @glossary.each do |source_term, locale_translations|
          next unless fuzzy_match?(source_term, source_text)

          # Try canonical locale first, then language-only, then any matching language
          translation = locale_translations[canonical] ||
                        locale_translations[language_only] ||
                        find_language_match(locale_translations, language_only)

          result[source_term] = translation if translation
        end

        result
      end

      private

      # Loads a curated JSON glossary file.
      # Format: { "source term": { "locale": "translation", ... }, ... }
      #
      # @param path [String] Path to the JSON glossary file
      def load_from_file(path)
        unless File.exist?(path)
          UI.warning("Glossary file not found: #{path}")
          return
        end

        UI.message("Glossary: Loading curated glossary from #{path}")
        data = JSON.parse(File.read(path))

        data.each do |source_term, translations|
          next unless translations.is_a?(Hash)

          @glossary[source_term] ||= {}
          # Canonicalize locale keys so 'fr-FR', 'fr_FR', 'fr' all resolve consistently
          translations.each do |locale, translation|
            canonical = canonicalize_locale(locale)
            @glossary[source_term][canonical] ||= translation
          end
        end
      rescue JSON::ParserError => e
        UI.error("Failed to parse glossary file #{path}: #{e.message}")
      end

      # Scans a directory for localization files and extracts glossary terms.
      #
      # @param dir [String] Path to the directory containing localization files
      def load_from_directory(dir)
        unless Dir.exist?(dir)
          UI.warning("Glossary directory not found: #{dir}")
          return
        end

        format = detect_format(dir)
        unless format
          UI.warning("No supported localization files found in #{dir}")
          return
        end

        UI.message("Detected glossary format: #{format}")
        locale_files = find_locale_files(dir, format)

        source_key = find_source_locale_key(locale_files)
        unless source_key
          UI.warning("Source locale '#{@source_locale}' not found in #{dir}")
          return
        end

        source_file = locale_files[source_key]
        source_strings = parse_file(source_file, format)

        locale_files.each do |locale, file_path|
          next if locale == source_key

          target_strings = parse_file(file_path, format)
          merge_locale_strings(source_strings, target_strings, locale)
        end
      end

      # Detects the localization format from files in the directory.
      #
      # @param dir [String] Directory path
      # @return [Symbol, nil] Format identifier or nil
      def detect_format(dir)
        # Check for .lproj subdirectories (iOS .strings)
        return :strings if Dir.glob(File.join(dir, '**', '*.lproj')).any?

        # Check for Android values-* directories
        return :android_xml if Dir.glob(File.join(dir, 'values*', '*.xml')).any?

        # Check files by extension
        files = Dir.glob(File.join(dir, '**', '*')).select { |f| File.file?(f) }
        files.each do |file|
          ext = File.extname(file).downcase
          return FORMAT_EXTENSIONS[ext] if FORMAT_EXTENSIONS.key?(ext)
        end

        nil
      end

      # Finds locale files in the directory based on format-specific patterns.
      #
      # @param dir [String] Directory path
      # @param format [Symbol] Format identifier
      # @return [Hash] { locale_code => file_path }
      def find_locale_files(dir, format)
        case format
        when :arb then find_arb_files(dir)
        when :strings then find_strings_files(dir)
        when :android_xml then find_android_xml_files(dir)
        when :json then find_json_files(dir)
        when :xliff then find_xliff_files(dir)
        else {}
        end
      end

      def find_arb_files(dir)
        files = {}
        Dir.glob(File.join(dir, '**', '*.arb')).each do |path|
          basename = File.basename(path, '.arb')
          # Match patterns: app_en, app_en_US, intl_en, en
          if basename =~ /(?:^|_)([a-z]{2}(?:[_-][A-Za-z]{2,})?)$/
            locale = canonicalize_locale(Regexp.last_match(1))
            files[locale] = path
          end
        end
        files
      end

      def find_strings_files(dir)
        files = {}
        Dir.glob(File.join(dir, '**', '*.lproj', '*.strings')).each do |path|
          lproj = File.basename(File.dirname(path), '.lproj')
          files[canonicalize_locale(lproj)] = path
        end
        files
      end

      def find_android_xml_files(dir)
        files = {}
        Dir.glob(File.join(dir, 'values*', '*.xml')).each do |path|
          values_dir = File.basename(File.dirname(path))
          if values_dir == 'values'
            files['default'] = path
          elsif values_dir =~ /^values-(.+)$/
            locale = Regexp.last_match(1)
            files[canonicalize_locale(locale)] = path
          end
        end
        files
      end

      def find_json_files(dir)
        files = {}
        Dir.glob(File.join(dir, '**', '*.json')).each do |path|
          basename = File.basename(path, '.json')
          # Match: en.json, en-US.json, messages_en.json
          if basename =~ /(?:^|_)([a-z]{2}(?:[_-][A-Za-z]{2,})?)$/
            locale = canonicalize_locale(Regexp.last_match(1))
            files[locale] = path
          elsif basename =~ /^([a-z]{2}(?:[_-][A-Za-z]{2,})?)$/
            locale = canonicalize_locale(Regexp.last_match(1))
            files[locale] = path
          end
        end
        files
      end

      def find_xliff_files(dir)
        files = {}
        Dir.glob(File.join(dir, '**', '*.{xliff,xlf}')).each do |path|
          doc = Nokogiri::XML(File.read(path))
          doc.remove_namespaces!
          doc.xpath('//file').each do |file_node|
            target_lang = file_node['target-language']
            source_lang = file_node['source-language']
            files[source_lang] = path if source_lang && !files.key?(source_lang)
            files[target_lang] = path if target_lang
          end
        end
        files
      end

      # Finds the source locale key in the locale files hash.
      # Tries canonical match, then language-only, then Android default.
      #
      # @param locale_files [Hash] Available locale files
      # @return [String, nil] The matching key or nil
      def find_source_locale_key(locale_files)
        canonical = canonicalize_locale(@source_locale)
        language_only = canonical.split('-').first

        # Canonical match (handles en-US == en_US == en-us)
        return canonical if locale_files.key?(canonical)

        # Language-only match (en-US -> en)
        return language_only if locale_files.key?(language_only)

        # Android default (values/ directory = source locale)
        return 'default' if locale_files.key?('default')

        # Last resort: any key sharing the same language
        locale_files.keys.find { |k| k.split('-').first == language_only }
      end

      # Parses a localization file based on its format.
      #
      # @param path [String] File path
      # @param format [Symbol] Format identifier
      # @return [Hash] { key => value } pairs
      def parse_file(path, format)
        case format
        when :arb then parse_arb(path)
        when :strings, :android_xml then parse_loco_strings(path)
        when :json then parse_json(path)
        when :xliff then parse_xliff(path)
        else {}
        end
      rescue StandardError => e
        UI.warning("Failed to parse #{path}: #{e.message}")
        {}
      end

      def parse_arb(path)
        data = JSON.parse(File.read(path))
        data.reject { |k, v| k.start_with?('@') || !v.is_a?(String) }
      end

      def parse_loco_strings(path)
        file = LocoStrings.load(path)
        strings = file.read
        strings.each_with_object({}) do |(key, loco_string), hash|
          hash[key] = loco_string.value if loco_string.respond_to?(:value) && loco_string.value
        end
      end

      def parse_json(path)
        data = JSON.parse(File.read(path))
        flatten_hash(data)
      end

      def parse_xliff(path)
        doc = Nokogiri::XML(File.read(path))
        doc.remove_namespaces!
        result = {}
        doc.xpath('//trans-unit').each do |unit|
          key = unit['id']
          source = unit.at_xpath('source')&.text
          target = unit.at_xpath('target')&.text
          result[key] = { source: source, target: target } if key && source
        end
        result
      end

      # Flattens a nested hash into dot-separated keys.
      #
      # @param hash [Hash] Nested hash
      # @param prefix [String] Key prefix for recursion
      # @return [Hash] Flat hash with dot-separated keys
      def flatten_hash(hash, prefix = '')
        hash.each_with_object({}) do |(k, v), result|
          key = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
          if v.is_a?(Hash)
            result.merge!(flatten_hash(v, key))
          elsif v.is_a?(String)
            result[key] = v
          end
        end
      end

      # Merges parsed locale strings into the glossary.
      # For XLIFF, uses source/target pairs directly.
      # For other formats, maps source values to target values by key.
      # Locale keys are canonicalized for consistent lookup.
      #
      # @param source_strings [Hash] Source locale key-value pairs
      # @param target_strings [Hash] Target locale key-value pairs
      # @param target_locale [String] Target locale code (already canonical from find_locale_files)
      def merge_locale_strings(source_strings, target_strings, target_locale)
        canonical_locale = canonicalize_locale(target_locale)

        if xliff_format?(source_strings)
          merge_xliff_strings(target_strings, canonical_locale)
        else
          source_strings.each do |key, source_value|
            target_value = target_strings[key]
            next unless target_value && !target_value.to_s.empty?
            next if source_value.to_s.empty?

            @glossary[source_value] ||= {}
            # Don't overwrite curated glossary entries
            @glossary[source_value][canonical_locale] ||= target_value
          end
        end
      end

      def xliff_format?(strings)
        strings.values.first.is_a?(Hash) && strings.values.first.key?(:source)
      end

      def merge_xliff_strings(strings, target_locale)
        strings.each do |_key, entry|
          next unless entry.is_a?(Hash) && entry[:source] && entry[:target]

          source_value = entry[:source]
          target_value = entry[:target]
          next if source_value.empty? || target_value.empty?

          @glossary[source_value] ||= {}
          @glossary[source_value][target_locale] ||= target_value
        end
      end

      # Fuzzy matches a glossary term against source text.
      # Case-insensitive substring matching + multi-word matching for significant words.
      # For multi-word terms, at least 2 significant (non-stopword, >= 4 char) words
      # must appear in the source text to qualify as a match.
      #
      # @param term [String] The glossary source term
      # @param text [String] The source text to match against
      # @return [Boolean] Whether the term matches
      def fuzzy_match?(term, text)
        return false if term.nil? || text.nil?
        return false if term.length < MIN_WORD_LENGTH
        return false if term.length > MAX_TERM_LENGTH

        # Ensure consistent UTF-8 encoding for comparison
        downcased_text = text.encode('UTF-8', invalid: :replace, undef: :replace).downcase
        downcased_term = term.encode('UTF-8', invalid: :replace, undef: :replace).downcase

        # Full term substring match (case-insensitive)
        return true if downcased_text.include?(downcased_term)

        # Multi-word matching: require at least 2 significant words to match
        words = downcased_term.split(/\s+/)
        return false if words.length <= 1

        significant_matches = words.count do |word|
          word.length >= MIN_WORD_LENGTH && !STOPWORDS.include?(word) && downcased_text.include?(word)
        end

        significant_matches >= 2
      end

      # Canonicalizes a locale code to a consistent format.
      # Handles various conventions: underscores, hyphens, Android 'r' prefix,
      # and case differences. Output is lowercase with hyphens.
      #
      # Examples:
      #   'en-US'   -> 'en-us'
      #   'en_US'   -> 'en-us'
      #   'en'      -> 'en'
      #   'en-rUS'  -> 'en-us'   (Android resource qualifier)
      #   'zh-Hans' -> 'zh-hans'
      #   'zh_Hant_TW' -> 'zh-hant-tw'
      #   'default' -> 'default' (Android values/ special case)
      #
      # @param locale [String] Locale code in any common format
      # @return [String] Canonical lowercase hyphen-separated locale
      def canonicalize_locale(locale)
        code = locale.to_s.strip
        return code if code == 'default'

        # Normalize separators: underscores to hyphens
        code = code.tr('_', '-')

        # Remove Android 'r' prefix from region codes (e.g., 'en-rUS' -> 'en-US')
        code = code.gsub(/\b([a-zA-Z]{2})-r([A-Z]{2})\b/, '\1-\2')

        code.downcase
      end

      # Finds a matching translation for a target locale by language code.
      # Used as a fallback when exact and language-only matches fail.
      # For example, glossary has 'fr-fr' but target is 'fr-ca'.
      #
      # @param translations [Hash] Available translations { locale => text }
      # @param language [String] Language code (e.g., 'fr', 'de')
      # @return [String, nil] Matching translation or nil
      def find_language_match(translations, language)
        translations.find { |locale, _| locale.split('-').first == language }&.last
      end
    end
  end
end
