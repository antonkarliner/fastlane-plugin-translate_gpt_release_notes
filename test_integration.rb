#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration Test for Multi-Provider Translation
# Tests all providers with real API calls using test fixtures

require 'fileutils'

# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

# Load required libraries and the plugin
require 'fastlane/plugin/translate_gpt_release_notes'

# Test configuration
TEST_CONFIG = {
  providers: %w[openai anthropic gemini deepl],
  platforms: %w[ios android],
  target_locales: %w[de-DE fr-FR ja-JP],
  master_locale: 'en-US',
  ios_source_file: 'test_fixtures/ios/metadata/en-US/release_notes.txt',
  android_source_file: 'test_fixtures/android/metadata/android/en-US/changelogs/100.txt',
  cleanup_after_test: ENV['CLEANUP'] == 'true'
}.freeze

# ANSI color codes for output
COLORS = {
  reset: "\e[0m",
  green: "\e[32m",
  red: "\e[31m",
  yellow: "\e[33m",
  blue: "\e[34m",
  cyan: "\e[36m",
  bold: "\e[1m"
}.freeze

# Helper methods for colored output
def colorize(text, color)
  "#{COLORS[color]}#{text}#{COLORS[:reset]}"
end

def print_header(text)
  puts "\n#{colorize('=' * 60, :bold)}"
  puts colorize(text, :bold)
  puts colorize('=' * 60, :bold)
end

def print_subheader(text)
  puts "\n#{colorize(text, :cyan)}"
  puts colorize('-' * 40, :cyan)
end

def print_success(message)
  puts "  #{colorize('✓', :green)} #{message}"
end

def print_error(message)
  puts "  #{colorize('✗', :red)} #{message}"
end

def print_warning(message)
  puts "  #{colorize('⚠', :yellow)} #{message}"
end

def print_info(message)
  puts "  #{colorize('ℹ', :blue)} #{message}"
end

# Statistics tracking
class TestStats
  attr_reader :results

  def initialize
    @results = {}
  end

  def add_result(provider, platform, locale, success, details = {})
    @results[provider] ||= {}
    @results[provider][platform] ||= {}
    @results[provider][platform][locale] = {
      success: success,
      details: details
    }
  end

  def provider_summary(provider)
    return { total: 0, successful: 0, skipped: 0 } unless @results[provider]

    total = 0
    successful = 0

    @results[provider].each do |_platform, locales|
      locales.each do |_locale, result|
        total += 1
        successful += 1 if result[:success]
      end
    end

    { total: total, successful: successful, skipped: 0 }
  end

  def overall_summary
    total = 0
    successful = 0
    skipped = 0

    @results.each do |provider, platforms|
      platforms.each do |_platform, locales|
        locales.each do |_locale, result|
          total += 1
          if result[:success]
            successful += 1
          elsif result[:details][:skipped]
            skipped += 1
          end
        end
      end
    end

    { total: total, successful: successful, skipped: skipped }
  end
end

$stats = TestStats.new

# Resolve API key for a provider
def resolve_api_key(provider_name)
  Fastlane::Helper::CredentialResolver.resolve(provider_name, {})
end

# Check if API key exists for a provider
def api_key_configured?(provider_name)
  !resolve_api_key(provider_name).nil?
end

# Get the source file path for a platform
def source_file_path(platform)
  case platform
  when 'ios'
    TEST_CONFIG[:ios_source_file]
  when 'android'
    TEST_CONFIG[:android_source_file]
  else
    raise "Unknown platform: #{platform}"
  end
end

# Get the target file path for a platform and locale
def target_file_path(platform, locale)
  case platform
  when 'ios'
    "test_fixtures/ios/metadata/#{locale}/release_notes.txt"
  when 'android'
    "test_fixtures/android/metadata/android/#{locale}/changelogs/100.txt"
  else
    raise "Unknown platform: #{platform}"
  end
end

# Read source text from master locale file
def read_source_text(platform)
  file_path = source_file_path(platform)
  return nil unless File.exist?(file_path)

  File.read(file_path)
end

# Write translated text to target file
def write_translation(platform, locale, text)
  file_path = target_file_path(platform, locale)
  FileUtils.mkdir_p(File.dirname(file_path))
  File.write(file_path, text)
  file_path
end

# Clean up translated files
def cleanup_translation(platform, locale)
  file_path = target_file_path(platform, locale)
  File.delete(file_path) if File.exist?(file_path)
end

# Create provider via factory
def create_provider(provider_name, platform)
  api_key = resolve_api_key(provider_name)
  return nil if api_key.nil?

  params = {
    api_token: api_key,
    platform: platform
  }

  # Add android_limitations for Android platform
  params[:android_limitations] = true if platform == 'android'

  Fastlane::Helper::Providers::ProviderFactory.create_with_key(provider_name, api_key, params)
rescue StandardError => e
  puts "  Error creating provider: #{e.message}"
  nil
end

# Perform translation
def perform_translation(provider, text, source_locale, target_locale)
  # Extract language code from locale (e.g., 'de-DE' -> 'de')
  source_lang = source_locale.split('-').first
  target_lang = target_locale.split('-').first

  provider.translate(text, source_lang, target_lang)
rescue StandardError => e
  puts "  Translation error: #{e.message}"
  nil
end

# Test translation for a single locale
def test_single_translation(provider_name, platform, target_locale)
  source_text = read_source_text(platform)

  if source_text.nil? || source_text.empty?
    print_error("No source text found for #{platform}")
    return { success: false, error: 'No source text' }
  end

  provider = create_provider(provider_name, platform)

  if provider.nil?
    print_error("Failed to create provider #{provider_name}")
    return { success: false, error: 'Provider creation failed' }
  end

  translated_text = perform_translation(
    provider,
    source_text,
    TEST_CONFIG[:master_locale],
    target_locale
  )

  if translated_text.nil? || translated_text.empty?
    print_error("#{target_locale}: Translation failed or returned empty")
    return { success: false, error: 'Translation failed' }
  end

  # Write translation to file
  file_path = write_translation(platform, target_locale, translated_text)

  # Verify file was created and has content
  unless File.exist?(file_path)
    print_error("#{target_locale}: File was not created")
    return { success: false, error: 'File not created' }
  end

  file_content = File.read(file_path)
  char_count = file_content.length

  if file_content.empty?
    print_error("#{target_locale}: File is empty")
    return { success: false, error: 'Empty file' }
  end

  # Display full translation
  puts "    Translation:"
  translated_text.each_line { |line| puts "      #{line}" }

  # Check Android character limit
  if platform == 'android'
    limit = Fastlane::Helper::Providers::BaseProvider::ANDROID_CHAR_LIMIT
    if char_count > limit
      print_warning("#{target_locale}: #{char_count} chars (exceeds #{limit} limit)")
    else
      print_success("#{target_locale}: #{char_count} chars (within #{limit} limit)")
    end
  else
    print_success("#{target_locale}: #{char_count} chars")
  end

  { success: true, char_count: char_count, file_path: file_path }
end

# Test all translations for a platform
def test_platform_translations(provider_name, platform)
  print_subheader("Testing #{platform.upcase} translation...")

  source_text = read_source_text(platform)
  if source_text.nil?
    print_error("Source file not found for #{platform}")
    return
  end

  print_info("Source text: #{source_text.length} chars")

  TEST_CONFIG[:target_locales].each do |locale|
    start_time = Time.now
    result = test_single_translation(provider_name, platform, locale)
    duration = Time.now - start_time

    result[:duration] = duration.round(2)
    $stats.add_result(provider_name, platform, locale, result[:success], result)

    # Clean up if requested
    if TEST_CONFIG[:cleanup_after_test] && result[:success]
      cleanup_translation(platform, locale)
    end

    sleep(0.5) # Small delay between requests to avoid rate limiting
  end
end

# Test a single provider
def test_provider(provider_name)
  print_header("Testing #{provider_name.upcase}")

  api_key = resolve_api_key(provider_name)

  if api_key.nil?
    print_warning("No API key configured for #{provider_name}")
    print_info("Expected env vars: #{Fastlane::Helper::CredentialResolver::PROVIDER_CREDENTIALS[provider_name][:env_vars].join(', ')}")

    # Mark all as skipped
    TEST_CONFIG[:platforms].each do |platform|
      TEST_CONFIG[:target_locales].each do |locale|
        $stats.add_result(provider_name, platform, locale, false, { skipped: true })
      end
    end
    return
  end

  print_success("API key found")
  provider_start_time = Time.now

  # Test each platform
  TEST_CONFIG[:platforms].each do |platform|
    test_platform_translations(provider_name, platform)
  end

  provider_duration = Time.now - provider_start_time
  puts "\n#{colorize("Duration: #{provider_duration.round(1)}s", :cyan)}"
rescue StandardError => e
  print_error("Error testing #{provider_name}: #{e.message}")
  puts e.backtrace.first(5).join("\n")
end

# Print summary report
def print_summary
  print_header("Summary")

  summary = $stats.overall_summary
  tested_providers = TEST_CONFIG[:providers]

  tested_providers.each do |provider|
    provider_stats = $stats.provider_summary(provider)

    if provider_stats[:total] == 0
      puts "#{colorize(provider.upcase, :bold)}: #{colorize('Skipped (no API key)', :yellow)}"
    else
      status = provider_stats[:successful] == provider_stats[:total] ? :green : :red
      puts "#{colorize(provider.upcase, :bold)}: #{colorize("#{provider_stats[:successful]}/#{provider_stats[:total]} translations successful", status)}"
    end
  end

  puts "\n#{colorize('Overall:', :bold)} #{colorize("#{summary[:successful]}/#{summary[:total]} successful", summary[:successful] == summary[:total] ? :green : :yellow)}"
  puts "#{colorize('Skipped:', :bold)} #{summary[:skipped]} (no API key)" if summary[:skipped] > 0

  # Print cleanup status
  if TEST_CONFIG[:cleanup_after_test]
    puts "\n#{colorize('Cleanup:', :bold)} Translated files have been removed"
  else
    puts "\n#{colorize('Cleanup:', :bold)} Translated files are preserved for manual verification"
    puts "        Set CLEANUP=true to remove them automatically"
  end
end

# Main execution
def main
  print_header("Integration Test for Multi-Provider Translation")

  puts "\n#{colorize('Configuration:', :bold)}"
  puts "  Providers: #{TEST_CONFIG[:providers].join(', ')}"
  puts "  Platforms: #{TEST_CONFIG[:platforms].join(', ')}"
  puts "  Target locales: #{TEST_CONFIG[:target_locales].join(', ')}"
  puts "  Master locale: #{TEST_CONFIG[:master_locale]}"
  puts "  Cleanup: #{TEST_CONFIG[:cleanup_after_test]}"

  # Test each provider
  TEST_CONFIG[:providers].each do |provider_name|
    test_provider(provider_name)
  end

  # Print summary
  print_summary

  # Exit with appropriate code
  summary = $stats.overall_summary
  exit_code = summary[:successful] == summary[:total] ? 0 : 1
  exit exit_code
end

# Run main if executed directly
main if __FILE__ == $PROGRAM_NAME
