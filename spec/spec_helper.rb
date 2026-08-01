$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'

# SimpleCov.minimum_coverage 95
SimpleCov.start

# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require 'fastlane' # to import the Action super class
require 'fastlane/plugin/translate_gpt_release_notes' # import the actual plugin

Fastlane.load_actions # load other actions (in case your plugin calls other actions or shared values)

# Fastlane::UI delegates all calls via method_missing. Explicitly define the
# most-stubbed methods so verify_partial_doubles can mock them in specs.
%i[message error important user_error!].each do |m|
  next if Fastlane::UI.respond_to?(m, true)

  Fastlane::UI.define_singleton_method(m) { |*args, &blk| ui_object.public_send(__method__, *args, &blk) }
end

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # Fail fast if a spec mocks a method that doesn't exist on the real object.
    # This catches provider code drifting from the actual SDK API.
    mocks.verify_partial_doubles = true
  end
end
