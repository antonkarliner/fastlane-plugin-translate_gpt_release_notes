require 'tmpdir'
require 'fileutils'

describe 'Optional Jev translation quality checks' do
  let(:provider) { instance_double(Fastlane::Helper::Providers::BaseProvider, valid?: true, translate: 'notes traduites') }
  let(:evaluator) { instance_double(Fastlane::Helper::TranslationEvaluator) }
  let(:params) { { provider: 'openai', platform: 'ios', master_locale: 'en-US', jev_check: true } }
  let(:warning) do
    { status: 'checked', model: 'jev-1.13.0', probabilities: { 'omission' => 0.85 }, warnings: { 'omission' => 0.85 } }
  end

  before do
    allow(Fastlane::Helper::Providers::ProviderFactory).to receive(:create).and_return(provider)
    allow(Fastlane::Helper::CredentialResolver).to receive(:credentials_exist?).and_return(true)
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:important)
  end

  def with_metadata
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        %w[en-US fr-FR].each { |locale| FileUtils.mkdir_p("fastlane/metadata/#{locale}") }
        File.write('fastlane/metadata/en-US/release_notes.txt', 'New features')
        yield
      end
    end
  end

  it 'does not instantiate or call Jev by default' do
    params.delete(:jev_check)
    expect(Fastlane::Helper::TranslationEvaluator).not_to receive(:new)
    helper = Fastlane::Helper::TranslateGptReleaseNotesHelper.new(params)
    expect(helper.translate_text('New features', 'fr-FR', 'ios')).to eq('notes traduites')
    expect(helper.quality_checks).to eq({})
  end

  it 'checks the final provider output and forwards the matched glossary and platform' do
    glossary = instance_double(Fastlane::Helper::GlossaryLoader, terms_for: { 'New features' => 'Nouvelles fonctionnalités' })
    params[:glossary] = 'unused.json'
    allow(Fastlane::Helper::GlossaryLoader).to receive(:new).and_return(glossary)
    expect(Fastlane::Helper::TranslationEvaluator).to receive(:new).with(params).and_return(evaluator)
    expect(evaluator).to receive(:evaluate).with('New features', 'notes traduites', 'en-US', 'fr-FR',
                                               glossary_terms: { 'New features' => 'Nouvelles fonctionnalités' }, platform: 'android').and_return(warning)
    helper = Fastlane::Helper::TranslateGptReleaseNotesHelper.new(params)
    expect(helper.translate_text('New features', 'fr-FR', 'android')).to eq('notes traduites')
    expect(helper.quality_checks['fr-FR']).to eq(warning)
    expect(Fastlane::UI).to have_received(:important).with(/quality warning.*omission=0.85/)
  end

  [['Shortened translation.', 'Shortened translation.'], ['b' * 520, 'b' * 500]].each do |second_draft, final_text|
    it "evaluates only the final Android text after shortening or fallback (#{final_text.length} chars)" do
      params.merge!(platform: 'android', android_length_retries: 1)
      client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).and_return(client)
      expect(client).to receive(:chat).twice.and_return(
        { 'choices' => [{ 'message' => { 'content' => 'a' * 563 } }] },
        { 'choices' => [{ 'message' => { 'content' => second_draft } }] }
      )
      actual_provider = Fastlane::Helper::Providers::OpenAIProvider.new(params.merge(api_token: 'test-key'))
      allow(Fastlane::Helper::Providers::ProviderFactory).to receive(:create).and_return(actual_provider)
      allow(Fastlane::Helper::TranslationEvaluator).to receive(:new).and_return(evaluator)
      expect(evaluator).to receive(:evaluate).once.with('New features', final_text, 'en-US', 'fr-FR',
                                                      glossary_terms: {}, platform: 'android').and_return(warning)
      helper = Fastlane::Helper::TranslateGptReleaseNotesHelper.new(params)
      expect(helper.translate_text('New features', 'fr-FR', 'android')).to eq(final_text)
    end
  end

  [nil, '', '  '].each do |empty|
    it "does not evaluate failed or empty translations: #{empty.inspect}" do
      allow(provider).to receive(:translate).and_return(empty)
      allow(Fastlane::Helper::TranslationEvaluator).to receive(:new).and_return(evaluator)
      expect(evaluator).not_to receive(:evaluate)
      helper = Fastlane::Helper::TranslateGptReleaseNotesHelper.new(params)
      expect(helper.translate_text('New features', 'fr-FR', 'ios')).to eq(empty)
      expect(helper.quality_checks).to eq({})
    end
  end

  it 'writes flagged translations and exposes per-locale results in lane context' do
    allow(Fastlane::Helper::TranslationEvaluator).to receive(:new).and_return(evaluator)
    allow(evaluator).to receive(:evaluate).and_return(warning)
    with_metadata do
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(params)
      expect(File.read('fastlane/metadata/fr-FR/release_notes.txt')).to eq('notes traduites')
      expect(File.exist?('last_successful_run.txt')).to be true
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::JEV_TRANSLATION_CHECKS]).to eq('fr-FR' => warning)
    end
  end

  it 'retains translations and reports checker unavailability' do
    allow(Fastlane::Helper::TranslationEvaluator).to receive(:new).and_return(evaluator)
    allow(evaluator).to receive(:evaluate).and_return(status: 'unavailable', error: 'HTTP 529')
    with_metadata do
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(params)
      expect(File.read('fastlane/metadata/fr-FR/release_notes.txt')).to eq('notes traduites')
      expect(Fastlane::UI).to have_received(:important).with(/check unavailable.*HTTP 529/)
    end
  end

  it 'reports quality warnings during dry run without writing files or a run marker' do
    allow(Fastlane::Helper::TranslationEvaluator).to receive(:new).and_return(evaluator)
    allow(evaluator).to receive(:evaluate).and_return(warning)
    with_metadata do
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(params.merge(dry_run: true))
      expect(evaluator).to have_received(:evaluate)
      expect(Fastlane::UI).to have_received(:important).with(/quality warning/)
      expect(File.exist?('fastlane/metadata/fr-FR/release_notes.txt')).to be false
      expect(File.exist?('last_successful_run.txt')).to be false
    end
  end

  it 'clears results from a previous run when translation is skipped' do
    Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::JEV_TRANSLATION_CHECKS] = { 'old-locale' => warning }
    with_metadata do
      File.write('last_successful_run.txt', (Time.now.to_i + 3600).to_s)
      expect(Fastlane::Helper::TranslationEvaluator).not_to receive(:new)
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(params)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::JEV_TRANSLATION_CHECKS]).to eq({})
    end
  end

  it 'defines opt-in and sensitive credential options' do
    options = Fastlane::Actions::TranslateGptReleaseNotesAction.available_options
    expect(options.find { |o| o.key == :jev_check }.default_value).to be false
    expect(options.find { |o| o.key == :jev_model }.default_value).to eq('jev-1.13.0')
    expect(options.find { |o| o.key == :typesafe_api_key }.sensitive).to be true
  end

  it 'excludes Syncthing conflict copies from automatic loading' do
    classes = Fastlane::TranslateGptReleaseNotes.all_classes
    expect(classes).to include(a_string_ending_with('/translation_evaluator.rb'))
    expect(classes.grep(/\.sync-conflict-/)).to be_empty
  end

  it 'validates threshold bounds and rejects nonfinite values' do
    option = Fastlane::Actions::TranslateGptReleaseNotesAction.available_options.find { |o| o.key == :jev_threshold }
    [0.0, 0.5, 1.0].each { |value| expect { option.verify!(value) }.not_to raise_error }
    [-0.1, 1.1, Float::NAN, Float::INFINITY].each do |value|
      expect { option.verify!(value) }.to raise_error(FastlaneCore::Interface::FastlaneError, /between 0 and 1/)
    end
  end

  it 'validates that timeouts are positive' do
    option = Fastlane::Actions::TranslateGptReleaseNotesAction.available_options.find { |o| o.key == :jev_timeout }
    expect { option.verify!(1) }.not_to raise_error
    [0, -1].each do |value|
      expect { option.verify!(value) }.to raise_error(FastlaneCore::Interface::FastlaneError, /positive/)
    end
  end
end
