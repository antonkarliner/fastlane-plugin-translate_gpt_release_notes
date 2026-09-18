require 'fastlane/plugin/translate_gpt_release_notes/version'

module Fastlane
  module TranslateGptReleaseNotes
    # Return all .rb files inside the "actions" and "helper" directory
    def self.all_classes
      Dir[File.expand_path('**/{actions,helper}/*.rb', File.dirname(__FILE__))].reject do |path|
        File.basename(path).include?('.sync-conflict-')
      end
    end
  end
end

# By default we want to import all available actions and helpers
# A plugin can contain any number of actions and plugins
Fastlane::TranslateGptReleaseNotes.all_classes.each do |current|
  require current
end
