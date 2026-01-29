describe Fastlane::Helper::Providers::DeepLProvider do
  let(:valid_params) do
    {
      api_token: 'test-token',
      platform: 'ios'
    }
  end

  before do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:error)
    allow(Fastlane::UI).to receive(:warning)
  end

  describe '.provider_name' do
    it 'returns deepl' do
      expect(described_class.provider_name).to eq('deepl')
    end
  end

  describe '.display_name' do
    it 'returns DeepL' do
      expect(described_class.display_name).to eq('DeepL')
    end
  end

  describe '.required_credentials' do
    it 'returns [:api_token]' do
      expect(described_class.required_credentials).to eq([:api_token])
    end
  end

  describe '.optional_params' do
    it 'returns hash with request_timeout and formality' do
      optional = described_class.optional_params

      expect(optional).to have_key(:request_timeout)
      expect(optional).to have_key(:formality)
    end

    it 'has correct default values' do
      optional = described_class.optional_params

      expect(optional[:request_timeout][:default]).to eq(30)
      expect(optional[:formality][:default]).to eq('default')
    end
  end

  describe '#initialize' do
    context 'with valid credentials' do
      it 'creates provider with valid credentials' do
        expect(DeepL).to receive(:configure)

        expect { described_class.new(valid_params) }.not_to raise_error
      end

      it 'configures DeepL with correct auth_key' do
        expect(DeepL).to receive(:configure) do |&block|
          config = double('config')
          expect(config).to receive(:auth_key=).with('test-token')
          expect(config).to receive(:host=).with('https://api.deepl.com')
          block.call(config)
        end

        described_class.new(valid_params)
      end

      it 'configures DeepL with correct host' do
        expect(DeepL).to receive(:configure) do |&block|
          config = double('config')
          allow(config).to receive(:auth_key=)
          expect(config).to receive(:host=).with('https://api.deepl.com')
          block.call(config)
        end

        described_class.new(valid_params)
      end
    end

    context 'with invalid credentials' do
      it 'adds config error when api_token is missing' do
        provider = described_class.new(valid_params.merge(api_token: nil))
        expect(provider).not_to be_valid
      end

      it 'adds config error when api_token is empty' do
        provider = described_class.new(valid_params.merge(api_token: ''))
        expect(provider).not_to be_valid
      end

      it 'reports error via UI' do
        allow(DeepL).to receive(:configure)
        expect(Fastlane::UI).to receive(:error).with(/Missing required credential/)

        described_class.new(valid_params.merge(api_token: nil))
      end
    end
  end

  describe '#translate' do
    let(:mock_result) { instance_double(DeepL::Resources::Text, text: 'Hallo Welt') }

    before do
      allow(DeepL).to receive(:configure)
    end

    context 'on successful translation' do
      it 'returns translated text' do
        allow(DeepL).to receive(:translate).and_return(mock_result)

        provider = described_class.new(valid_params)
        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to eq('Hallo Welt')
      end

      it 'normalizes source locale from en-US to EN' do
        expect(DeepL).to receive(:translate).with(
          'Hello World', 'EN', 'DE', anything
        ).and_return(mock_result)

        provider = described_class.new(valid_params)
        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'normalizes target locale from de-DE to DE' do
        expect(DeepL).to receive(:translate).with(
          'Hello World', 'EN', 'DE', anything
        ).and_return(mock_result)

        provider = described_class.new(valid_params)
        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'handles simple locale codes' do
        expect(DeepL).to receive(:translate).with(
          'Hello', 'EN', 'FR', anything
        ).and_return(mock_result)

        provider = described_class.new(valid_params)
        provider.translate('Hello', 'en', 'fr')
      end

      it 'handles context parameter' do
        expect(DeepL).to receive(:translate).with(
          'Hello World', 'EN', 'DE', hash_including(context: 'Mobile app update')
        ).and_return(mock_result)

        provider = described_class.new(valid_params.merge(context: 'Mobile app update'))
        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'includes formality option when specified' do
        expect(DeepL).to receive(:translate).with(
          'Hello World', 'EN', 'DE', hash_including(formality: 'more')
        ).and_return(mock_result)

        provider = described_class.new(valid_params.merge(formality: 'more'))
        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'excludes formality when set to default' do
        expect(DeepL).to receive(:translate).with(
          'Hello World', 'EN', 'DE', hash_excluding(:formality)
        ).and_return(mock_result)

        provider = described_class.new(valid_params.merge(formality: 'default'))
        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'excludes formality when empty string' do
        expect(DeepL).to receive(:translate).with(
          'Hello World', 'EN', 'DE', hash_excluding(:formality)
        ).and_return(mock_result)

        provider = described_class.new(valid_params.merge(formality: ''))
        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'excludes formality when whitespace only' do
        expect(DeepL).to receive(:translate).with(
          'Hello World', 'EN', 'DE', hash_excluding(:formality)
        ).and_return(mock_result)

        provider = described_class.new(valid_params.merge(formality: '  '))
        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'excludes context when empty string' do
        expect(DeepL).to receive(:translate).with(
          'Hello World', 'EN', 'DE', hash_excluding(:context)
        ).and_return(mock_result)

        provider = described_class.new(valid_params.merge(context: ''))
        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'with Android platform limitations' do
      let(:android_params) { valid_params.merge(platform: 'android') }
      let(:long_text) { 'A' * 600 }
      let(:truncated_result) { instance_double(DeepL::Resources::Text, text: long_text) }

      it 'truncates translation exceeding 500 characters' do
        allow(DeepL).to receive(:translate).and_return(truncated_result)

        provider = described_class.new(android_params)

        expect(Fastlane::UI).to receive(:warning).with(/exceeds 500 characters/)

        result = provider.translate(long_text, 'en-US', 'de-DE')
        expect(result.length).to eq(500)
      end

      it 'does not truncate translation under 500 characters' do
        short_result = instance_double(DeepL::Resources::Text, text: 'Short')
        allow(DeepL).to receive(:translate).and_return(short_result)

        provider = described_class.new(android_params)

        expect(Fastlane::UI).not_to receive(:warning)

        result = provider.translate('Short', 'en-US', 'de-DE')
        expect(result).to eq('Short')
      end

      it 'does not truncate for non-Android platform' do
        allow(DeepL).to receive(:translate).and_return(truncated_result)

        provider = described_class.new(valid_params.merge(platform: 'ios'))

        expect(Fastlane::UI).not_to receive(:warning)

        result = provider.translate(long_text, 'en-US', 'de-DE')
        expect(result.length).to eq(600)
      end
    end

    context 'on DeepL::Exceptions::RequestError' do
      it 'returns nil on DeepL::Exceptions::RequestError' do
        allow(DeepL).to receive(:translate).and_raise(
          DeepL::Exceptions::RequestError.new('Invalid API key')
        )

        provider = described_class.new(valid_params)
        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'logs error message' do
        allow(DeepL).to receive(:translate).and_raise(
          DeepL::Exceptions::RequestError.new('Invalid API key')
        )

        expect(Fastlane::UI).to receive(:error).with(/DeepL API error:/)

        provider = described_class.new(valid_params)
        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'on StandardError' do
      it 'returns nil on StandardError' do
        allow(DeepL).to receive(:translate).and_raise(StandardError.new('Network error'))

        provider = described_class.new(valid_params)
        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'logs error message' do
        allow(DeepL).to receive(:translate).and_raise(StandardError.new('Network error'))

        expect(Fastlane::UI).to receive(:error).with(/DeepL provider error: Network error/)

        provider = described_class.new(valid_params)
        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end
  end

  describe '#valid?' do
    it 'returns true when no config errors' do
      allow(DeepL).to receive(:configure)
      provider = described_class.new(valid_params)
      expect(provider).to be_valid
    end

    it 'returns false when there are config errors' do
      provider = described_class.new(valid_params.merge(api_token: nil))
      expect(provider).not_to be_valid
    end
  end

  describe '#params' do
    it 'returns the params hash' do
      allow(DeepL).to receive(:configure)
      provider = described_class.new(valid_params)
      expect(provider.params).to eq(valid_params)
    end
  end

  describe '#config_errors' do
    it 'returns empty array for valid params' do
      allow(DeepL).to receive(:configure)
      provider = described_class.new(valid_params)
      expect(provider.config_errors).to be_empty
    end

    it 'returns array of error messages for invalid params' do
      provider = described_class.new(valid_params.merge(api_token: nil))
      expect(provider.config_errors).not_to be_empty
      expect(provider.config_errors.first).to include('Missing required credential')
    end
  end

  describe 'locale normalization' do
    before do
      allow(DeepL).to receive(:configure)
    end

    it 'converts en-US to EN' do
      mock_result = instance_double(DeepL::Resources::Text, text: 'Test')
      expect(DeepL).to receive(:translate).with('Test', 'EN', 'DE', anything).and_return(mock_result)

      provider = described_class.new(valid_params)
      provider.translate('Test', 'en-US', 'de-DE')
    end

    it 'converts zh-Hans to ZH' do
      mock_result = instance_double(DeepL::Resources::Text, text: '测试')
      expect(DeepL).to receive(:translate).with('Test', 'ZH', 'JA', anything).and_return(mock_result)

      provider = described_class.new(valid_params)
      provider.translate('Test', 'zh-Hans', 'ja-JP')
    end

    it 'converts pt-BR to PT' do
      mock_result = instance_double(DeepL::Resources::Text, text: 'Teste')
      expect(DeepL).to receive(:translate).with('Test', 'PT', 'ES', anything).and_return(mock_result)

      provider = described_class.new(valid_params)
      provider.translate('Test', 'pt-BR', 'es-ES')
    end

    it 'handles uppercase locales' do
      mock_result = instance_double(DeepL::Resources::Text, text: 'Test')
      expect(DeepL).to receive(:translate).with('Test', 'FR', 'IT', anything).and_return(mock_result)

      provider = described_class.new(valid_params)
      provider.translate('Test', 'FR-FR', 'IT-IT')
    end
  end
end
