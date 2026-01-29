describe Fastlane::Actions::TranslateGptReleaseNotesAction do
  describe '#run' do
    before(:each) do
      # Mock credentials to exist by default for provider tests
      allow(Fastlane::Helper::CredentialResolver).to receive(:credentials_exist?).and_return(true)
      allow(Fastlane::Helper::CredentialResolver).to receive(:available_providers).and_return(['openai', 'anthropic', 'gemini', 'deepl'])
      allow(Fastlane::Helper::CredentialResolver).to receive(:resolve).and_return('test-api-key')
    end

    context 'with basic parameters' do
      it 'handles missing directory gracefully' do
        # Mock the required parameters
        params = {
          platform: 'ios',
          master_locale: 'en-US',
          api_token: 'test_token'
        }

        # Mock the UI and file operations
        allow(Fastlane::UI).to receive(:message)
        allow(Fastlane::UI).to receive(:error)
        allow(Dir).to receive(:exist?).and_return(false)

        Fastlane::Actions::TranslateGptReleaseNotesAction.run(params)
      end
    end

    context 'with provider parameter' do
      it 'accepts valid provider names' do
        params = {
          provider: 'openai',
          platform: 'ios',
          master_locale: 'en-US',
          openai_api_key: 'test-key'
        }
        allow(Dir).to receive(:exist?).and_return(false)

        expect { Fastlane::Actions::TranslateGptReleaseNotesAction.run(params) }.not_to raise_error
      end

     it 'raises error for invalid provider' do
       params = {
         provider: 'invalid_provider',
         platform: 'ios',
         master_locale: 'en-US'
       }

       allow(Fastlane::Helper::CredentialResolver).to receive(:credentials_exist?).with('invalid_provider', params).and_return(false)
       allow(Fastlane::Helper::CredentialResolver).to receive(:available_providers).and_return(['openai'])

       expect(Fastlane::UI).to receive(:user_error!).with(/Provider 'invalid_provider' has no credentials/)
       Fastlane::Actions::TranslateGptReleaseNotesAction.run(params)
     end
    end

    context 'with credential validation' do
      it 'checks for provider credentials before running' do
        params = {
          provider: 'anthropic',
          platform: 'ios',
          master_locale: 'en-US'
        }

        allow(Fastlane::Helper::CredentialResolver).to receive(:credentials_exist?).with('anthropic', params).and_return(false)
        allow(Fastlane::Helper::CredentialResolver).to receive(:available_providers).and_return(['openai'])

        expect(Fastlane::UI).to receive(:user_error!).with(/Provider 'anthropic' has no credentials/)
        Fastlane::Actions::TranslateGptReleaseNotesAction.run(params)
      end
    end

    context 'with provider-specific API keys' do
      it 'accepts openai_api_key parameter' do
        params = {
          provider: 'openai',
          platform: 'ios',
          master_locale: 'en-US',
          openai_api_key: 'test-openai-key'
        }

        allow(Dir).to receive(:exist?).and_return(false)
        expect { Fastlane::Actions::TranslateGptReleaseNotesAction.run(params) }.not_to raise_error
      end

      it 'accepts anthropic_api_key parameter' do
        params = {
          provider: 'anthropic',
          platform: 'ios',
          master_locale: 'en-US',
          anthropic_api_key: 'test-anthropic-key'
        }

        allow(Dir).to receive(:exist?).and_return(false)
        expect { Fastlane::Actions::TranslateGptReleaseNotesAction.run(params) }.not_to raise_error
      end
    end

    context 'backward compatibility' do
      it 'defaults to openai provider when not specified' do
        params = {
          platform: 'ios',
          master_locale: 'en-US',
          api_token: 'legacy-gpt-key'  # Old parameter name
        }

        allow(Fastlane::Helper::CredentialResolver).to receive(:resolve).and_return('legacy-gpt-key')
        allow(Dir).to receive(:exist?).and_return(false)

        expect { Fastlane::Actions::TranslateGptReleaseNotesAction.run(params) }.not_to raise_error
      end
    end
  end

  describe '.available_options' do
    it 'includes provider option' do
      options = Fastlane::Actions::TranslateGptReleaseNotesAction.available_options
      provider_option = options.find { |opt| opt.key == :provider }
      expect(provider_option).not_to be_nil
      expect(provider_option.default_value).to eq('openai')
    end

    it 'includes provider-specific API key options' do
      options = Fastlane::Actions::TranslateGptReleaseNotesAction.available_options
      expect(options.map(&:key)).to include(:openai_api_key, :anthropic_api_key, :gemini_api_key, :deepl_api_key)
    end
  end
end
