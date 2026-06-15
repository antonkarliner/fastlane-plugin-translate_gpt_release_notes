describe Fastlane::Helper::Providers::AnthropicProvider do
  let(:valid_params) do
    {
      api_token: 'test-token',
      model_name: 'claude-sonnet-4-5',
      temperature: 0.5,
      max_tokens: 1024,
      platform: 'ios'
    }
  end

  let(:mock_client) { double('Anthropic::Client') }

  before do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:error)
  end

  describe '.provider_name' do
    it 'returns anthropic' do
      expect(described_class.provider_name).to eq('anthropic')
    end
  end

  describe '.display_name' do
    it 'returns Anthropic Claude' do
      expect(described_class.display_name).to eq('Anthropic Claude')
    end
  end

  describe '.required_credentials' do
    it 'returns [:api_token]' do
      expect(described_class.required_credentials).to eq([:api_token])
    end
  end

  describe '.optional_params' do
    it 'returns hash with model_name, max_tokens, temperature, and request_timeout' do
      optional = described_class.optional_params

      expect(optional).to have_key(:model_name)
      expect(optional).to have_key(:max_tokens)
      expect(optional).to have_key(:temperature)
      expect(optional).to have_key(:request_timeout)
    end

    it 'has correct default values' do
      optional = described_class.optional_params

      expect(optional[:model_name][:default]).to eq('claude-sonnet-4.5')
      expect(optional[:max_tokens][:default]).to eq(1024)
      expect(optional[:temperature][:default]).to eq(0.5)
      expect(optional[:request_timeout][:default]).to eq(60)
    end
  end

  describe '#initialize' do
    context 'with valid credentials' do
      it 'creates provider with valid credentials' do
        expect(Anthropic::Client).to receive(:new).and_return(mock_client)

        expect { described_class.new(valid_params) }.not_to raise_error
      end

      it 'creates Anthropic client with correct api_key' do
        expect(Anthropic::Client).to receive(:new).with(
          hash_including(api_key: 'test-token')
        ).and_return(mock_client)

        described_class.new(valid_params)
      end

      it 'sets default timeout when not specified' do
        expect(Anthropic::Client).to receive(:new).with(
          hash_including(timeout: 60)
        ).and_return(mock_client)

        described_class.new(valid_params)
      end

      it 'sets custom timeout when specified' do
        params = valid_params.merge(request_timeout: 120)

        expect(Anthropic::Client).to receive(:new).with(
          hash_including(timeout: 120)
        ).and_return(mock_client)

        described_class.new(params)
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
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        expect(Fastlane::UI).to receive(:error).with(/Missing required credential/)

        described_class.new(valid_params.merge(api_token: nil))
      end
    end
  end

  describe '#translate' do
    let(:provider) { described_class.new(valid_params) }
    let(:messages_resource) { double('Anthropic::Resources::Messages') }

    def text_block(str)
      instance_double('Anthropic::Models::TextBlock', type: :text, text: str)
    end

    def message_with(str)
      instance_double('Anthropic::Models::Message', content: [text_block(str)])
    end

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:messages).and_return(messages_resource)
    end

    context 'on successful translation' do
      it 'returns translated text' do
        allow(messages_resource).to receive(:create).and_return(message_with('Hallo Welt'))

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to eq('Hallo Welt')
      end

      it 'strips whitespace from response' do
        allow(messages_resource).to receive(:create).and_return(message_with('  Hallo Welt  '))

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to eq('Hallo Welt')
      end

      it 'builds correct prompt with source and target locales' do
        expect(messages_resource).to receive(:create) do |args|
          expect(args[:system_]).to include('Translate the following release notes from en-US to de-DE')
          expect(args[:messages].first[:content]).to eq('Hello World')
          message_with('Hallo Welt')
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'uses custom model name when specified' do
        provider = described_class.new(valid_params.merge(model_name: 'claude-3-haiku'))
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)

        expect(messages_resource).to receive(:create).with(
          hash_including(model: 'claude-3-haiku')
        ).and_return(message_with('Translated'))

        provider.translate('Hello', 'en', 'de')
      end

      it 'uses custom temperature when specified' do
        provider = described_class.new(valid_params.merge(temperature: 0.8))
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)

        expect(messages_resource).to receive(:create).with(
          hash_including(temperature: 0.8)
        ).and_return(message_with('Translated'))

        provider.translate('Hello', 'en', 'de')
      end

      it 'uses custom max_tokens when specified' do
        provider = described_class.new(valid_params.merge(max_tokens: 2048))
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)

        expect(messages_resource).to receive(:create).with(
          hash_including(max_tokens: 2048)
        ).and_return(message_with('Translated'))

        provider.translate('Hello', 'en', 'de')
      end

      it 'converts temperature and max_tokens to correct types' do
        provider = described_class.new(valid_params.merge(temperature: '0.7', max_tokens: '512'))
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)

        expect(messages_resource).to receive(:create).with(
          hash_including(temperature: 0.7, max_tokens: 512)
        ).and_return(message_with('Translated'))

        provider.translate('Hello', 'en', 'de')
      end
    end

    context 'with glossary terms' do
      it 'includes glossary terms in system instruction' do
        expect(messages_resource).to receive(:create) do |args|
          expect(args[:system_]).to include('glossary for consistent terminology')
          expect(args[:system_]).to include('"Settings" -> "Parametres"')
          message_with('Hallo Welt')
        end

        provider.translate('Hello World', 'en-US', 'de-DE', glossary_terms: {
          "Settings" => "Parametres"
        })
      end

      it 'does not include glossary section when terms are empty' do
        expect(messages_resource).to receive(:create) do |args|
          expect(args[:system_]).not_to include('glossary')
          message_with('Hallo Welt')
        end

        provider.translate('Hello World', 'en-US', 'de-DE', glossary_terms: {})
      end
    end

    context 'with Android platform limitations' do
      let(:android_params) { valid_params.merge(platform: 'android') }
      let(:provider) do
        p = described_class.new(android_params)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        p
      end

      it 'includes Android character limit in system instruction' do
        expect(messages_resource).to receive(:create) do |args|
          expect(args[:system_]).to include('500 characters')
          expect(args[:system_]).to include('Google Play Store')
          message_with('Hallo Welt')
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'with context parameter' do
      let(:context_params) { valid_params.merge(context: 'This is a mobile app update') }
      let(:provider) do
        p = described_class.new(context_params)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        p
      end

      it 'includes context in system instruction' do
        expect(messages_resource).to receive(:create) do |args|
          expect(args[:system_]).to include('Context: This is a mobile app update')
          message_with('Hallo Welt')
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'on StandardError' do
      it 'returns nil on StandardError' do
        allow(messages_resource).to receive(:create).and_raise(StandardError.new('Network timeout'))

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'logs error message' do
        allow(messages_resource).to receive(:create).and_raise(StandardError.new('Network timeout'))

        expect(Fastlane::UI).to receive(:error).with(/Anthropic provider error: Network timeout/)

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'with default values' do
      let(:minimal_params) { { api_token: 'test-token' } }
      let(:provider) do
        p = described_class.new(minimal_params)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        p
      end

      it 'uses default model when not specified' do
        expect(messages_resource).to receive(:create).with(
          hash_including(model: 'claude-sonnet-4.5')
        ).and_return(message_with('Translated'))

        provider.translate('Hello', 'en', 'de')
      end

      it 'uses default max_tokens when not specified' do
        expect(messages_resource).to receive(:create).with(
          hash_including(max_tokens: 1024)
        ).and_return(message_with('Translated'))

        provider.translate('Hello', 'en', 'de')
      end

      it 'uses default temperature when not specified' do
        expect(messages_resource).to receive(:create).with(
          hash_including(temperature: 0.5)
        ).and_return(message_with('Translated'))

        provider.translate('Hello', 'en', 'de')
      end
    end
  end

  describe '#valid?' do
    it 'returns true when no config errors' do
      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
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
      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      provider = described_class.new(valid_params)
      expect(provider.params).to eq(valid_params)
    end
  end

  describe '#config_errors' do
    it 'returns empty array for valid params' do
      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      provider = described_class.new(valid_params)
      expect(provider.config_errors).to be_empty
    end

    it 'returns array of error messages for invalid params' do
      provider = described_class.new(valid_params.merge(api_token: nil))
      expect(provider.config_errors).not_to be_empty
      expect(provider.config_errors.first).to include('Missing required credential')
    end
  end
end
