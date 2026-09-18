require 'tmpdir'
require 'fileutils'

describe 'Android translation length retries' do
  shared_examples 'an Android shortening provider' do |provider_class|
    let(:params) do
      { api_token: 'test-key', platform: 'android', android_length_retries: 2, context: 'Coffee app' }
    end
    let(:provider) { provider_class.new(params) }
    let(:source) { 'Saved Recipes now work offline.' }
    let(:glossary) { { 'Saved Recipes' => 'Recettes enregistrées' } }
    let(:requests) { [] }
    let(:drafts) { ['a' * 563, 'Recettes enregistrées disponibles hors ligne.'] }

    before do
      allow(Fastlane::UI).to receive(:important)
      allow(Fastlane::UI).to receive(:error)
      allow(Fastlane::UI).to receive(:message)
      if provider_class == Fastlane::Helper::Providers::OpenAIProvider
        client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client)
        allow(client).to receive(:chat) do |parameters:|
          requests << { instruction: parameters[:messages][0][:content], text: parameters[:messages][1][:content] }
          draft = drafts.shift
          raise draft if draft.is_a?(Exception)

          { 'choices' => [{ 'message' => { 'content' => draft } }] }
        end
      elsif provider_class == Fastlane::Helper::Providers::AnthropicProvider
        client = double('Anthropic::Client')
        messages = double('Anthropic::Resources::Messages')
        allow(Anthropic::Client).to receive(:new).and_return(client)
        allow(client).to receive(:messages).and_return(messages)
        allow(messages).to receive(:create) do |arguments|
          requests << { instruction: arguments[:system_], text: arguments[:messages][0][:content] }
          draft = drafts.shift
          raise draft if draft.is_a?(Exception)

          blocks = draft.nil? ? [] : [instance_double('Anthropic::Models::TextBlock', type: :text, text: draft)]
          instance_double('Anthropic::Models::Message', content: blocks)
        end
      else
        allow(provider).to receive(:make_api_request) do |prompt|
          requests << { instruction: prompt, text: prompt }
          draft = drafts.shift
          raise draft if draft.is_a?(Exception)

          { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => draft }] } }] }
        end
      end
    end

    def translate
      provider.translate(source, 'en-US', 'fr-FR', glossary_terms: glossary)
    end

    it 'retries the untruncated draft with its measured length, original source, context and glossary' do
      result = translate
      expect(result).to eq('Recettes enregistrées disponibles hors ligne.')
      expect(requests.size).to eq(2)
      expect(requests[1][:instruction]).to include('563 characters', 'within 500 characters', 'complete sentences', 'Coffee app')
      expect(requests[1][:instruction]).to include('"Saved Recipes" -> "Recettes enregistrées"')
      expect(requests[1][:text]).to include(source, 'a' * 563)
      expect(Fastlane::UI).not_to have_received(:important).with(/truncating/)
    end

    it 'uses the latest draft and measured length for a second retry' do
      drafts.replace(['a' * 563, 'b' * 520, 'Final translation.'])
      expect(translate).to eq('Final translation.')
      expect(requests.size).to eq(3)
      expect(requests[2][:instruction]).to include('520 characters')
      expect(requests[2][:text]).to include(source, 'b' * 520)
    end

    it 'stops at the configured bound and truncates the shortest nonempty draft' do
      drafts.replace(['a' * 563, 'b' * 520, 'c' * 580])
      expect(translate).to eq('b' * 500)
      expect(requests.size).to eq(3)
      expect(Fastlane::UI).to have_received(:important).with(/520.*truncating/)
    end

    it 'honors a single retry' do
      params[:android_length_retries] = 1
      drafts.replace(['a' * 563, 'b' * 520, 'not requested'])
      expect(translate).to eq('b' * 500)
      expect(requests.size).to eq(2)
    end

    it 'retains the existing truncation behavior when retries are not configured' do
      params.delete(:android_length_retries)
      expect(translate).to eq('a' * 500)
      expect(requests.size).to eq(1)
    end

    it 'does not retry an oversized iOS translation' do
      params[:platform] = 'ios'
      expect(translate).to eq('a' * 563)
      expect(requests.size).to eq(1)
    end

    it 'accepts exactly 500 Unicode characters without counting bytes' do
      drafts.replace(['日' * 500])
      expect(translate).to eq('日' * 500)
      expect(requests.size).to eq(1)
    end

    it 'retries 501 characters rather than truncating the first draft' do
      drafts.replace(['日' * 501, 'Short result'])
      expect(translate).to eq('Short result')
      expect(requests.size).to eq(2)
      expect(requests[1][:instruction]).to include('501 characters')
    end

    [nil, '', '   '].each do |empty|
      it "retains the usable draft when shortening returns #{empty.inspect}" do
        drafts.replace(['a' * 563, empty])
        expect(translate).to eq('a' * 500)
        expect(requests.size).to eq(2)
      end
    end

    it 'retains the shortest draft if a later shortening request fails' do
      drafts.replace(['a' * 563, 'b' * 520, StandardError.new('test failure')])
      expect(translate).to eq('b' * 500)
      expect(requests.size).to eq(3)
      expect(Fastlane::UI).to have_received(:important).with(/shortening failed.*StandardError/)
    end

    it 'does not retry an initially failed translation' do
      drafts.replace([nil])
      expect(translate.to_s).to eq('')
      expect(requests.size).to eq(1)
    end
  end

  [Fastlane::Helper::Providers::OpenAIProvider,
   Fastlane::Helper::Providers::AnthropicProvider,
   Fastlane::Helper::Providers::GeminiProvider].each do |provider_class|
    context provider_class.display_name do
      include_examples 'an Android shortening provider', provider_class
    end
  end

  it 'leaves DeepL on its existing single-request truncation behavior' do
    allow(Fastlane::UI).to receive(:important)
    expect(DeepL).to receive(:translate).once.and_return(double(text: 'a' * 563))
    provider = Fastlane::Helper::Providers::DeepLProvider.new(api_token: 'test-key', platform: 'android', android_length_retries: 2)
    expect(provider.translate('source', 'en-US', 'fr-FR')).to eq('a' * 500)
  end

  [false, true].each do |dry_run|
    it "shortens through the Android action with Jev disabled (dry_run=#{dry_run})" do
      allow(Fastlane::UI).to receive(:message)
      allow(Fastlane::UI).to receive(:important)
      allow(Fastlane::Helper::CredentialResolver).to receive(:credentials_exist?).and_return(true)
      allow(Fastlane::Helper::CredentialResolver).to receive(:resolve).and_return('test-key')
      expect(Fastlane::Helper::TranslationEvaluator).not_to receive(:new)
      client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).and_return(client)
      expect(client).to receive(:chat).twice.and_return(
        { 'choices' => [{ 'message' => { 'content' => 'a' * 563 } }] },
        { 'choices' => [{ 'message' => { 'content' => 'Short translation.' } }] }
      )
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          %w[en-US fr-FR].each { |locale| FileUtils.mkdir_p("fastlane/metadata/android/#{locale}/changelogs") }
          File.write('fastlane/metadata/android/en-US/changelogs/100.txt', 'Original source')
          Fastlane::Actions::TranslateGptReleaseNotesAction.run(
            provider: 'openai', platform: 'android', master_locale: 'en-US', android_length_retries: 2, dry_run: dry_run
          )
          target = 'fastlane/metadata/android/fr-FR/changelogs/100.txt'
          if dry_run
            expect(File.exist?(target)).to be false
            expect(File.exist?('last_successful_run.txt')).to be false
          else
            expect(File.read(target)).to eq('Short translation.')
            expect(File.exist?('last_successful_run.txt')).to be true
          end
        end
      end
    end
  end

  it 'defines disabled-by-default retries with a bounded range' do
    option = Fastlane::Actions::TranslateGptReleaseNotesAction.available_options.find { |o| o.key == :android_length_retries }
    expect(option.default_value).to eq(0)
    [0, 1, 2].each { |value| expect { option.verify!(value) }.not_to raise_error }
    [-1, 3].each do |value|
      expect { option.verify!(value) }.to raise_error(FastlaneCore::Interface::FastlaneError, /between 0 and 2/)
    end
  end
end
