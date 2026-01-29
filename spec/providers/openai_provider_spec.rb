describe Fastlane::Helper::Providers::OpenAIProvider do
  let(:valid_params) do
    {
      api_token: 'test-token',
      model_name: 'gpt-4',
      temperature: 0.5,
      platform: 'ios'
    }
  end

  let(:mock_client) { instance_double(OpenAI::Client) }

  before do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:error)
  end

  describe '.provider_name' do
    it 'returns openai' do
      expect(described_class.provider_name).to eq('openai')
    end
  end

  describe '.display_name' do
    it 'returns OpenAI GPT' do
      expect(described_class.display_name).to eq('OpenAI GPT')
    end
  end

  describe '.required_credentials' do
    it 'returns [:api_token]' do
      expect(described_class.required_credentials).to eq([:api_token])
    end
  end

  describe '.optional_params' do
    it 'returns hash with model_name, temperature, service_tier, and request_timeout' do
      optional = described_class.optional_params

      expect(optional).to have_key(:model_name)
      expect(optional).to have_key(:temperature)
      expect(optional).to have_key(:service_tier)
      expect(optional).to have_key(:request_timeout)
    end

    it 'has correct default values' do
      optional = described_class.optional_params

      expect(optional[:model_name][:default]).to eq('gpt-5.2')
      expect(optional[:temperature][:default]).to eq(0.5)
      expect(optional[:request_timeout][:default]).to eq(30)
    end
  end

  describe '#initialize' do
    context 'with valid credentials' do
      it 'creates provider with valid credentials' do
        expect { described_class.new(valid_params) }.not_to raise_error
      end

      it 'creates OpenAI client with correct access_token' do
        expect(OpenAI::Client).to receive(:new).with(
          hash_including(access_token: 'test-token')
        ).and_return(mock_client)

        described_class.new(valid_params)
      end

      it 'sets default timeout when not specified' do
        expect(OpenAI::Client).to receive(:new).with(
          hash_including(request_timeout: 30)
        ).and_return(mock_client)

        described_class.new(valid_params)
      end

      it 'sets custom timeout when specified' do
        params = valid_params.merge(request_timeout: 60)

        expect(OpenAI::Client).to receive(:new).with(
          hash_including(request_timeout: 60)
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
        expect(Fastlane::UI).to receive(:error).with(/Missing required credential/)

        described_class.new(valid_params.merge(api_token: nil))
      end
    end

    context 'with service tier flex timeout adjustment' do
      it 'increases timeout to 900s for flex service tier' do
        params = valid_params.merge(service_tier: 'flex', request_timeout: 30)

        expect(Fastlane::UI).to receive(:message).with(/Flex processing detected.*900s/)
        expect(OpenAI::Client).to receive(:new).with(
          hash_including(request_timeout: 900)
        ).and_return(mock_client)

        described_class.new(params)
      end

      it 'does not change timeout when already >= 900s for flex tier' do
        params = valid_params.merge(service_tier: 'flex', request_timeout: 1000)

        expect(Fastlane::UI).not_to receive(:message)
        expect(OpenAI::Client).to receive(:new).with(
          hash_including(request_timeout: 1000)
        ).and_return(mock_client)

        described_class.new(params)
      end

      it 'does not change timeout for non-flex service tier' do
        params = valid_params.merge(service_tier: 'standard', request_timeout: 30)

        expect(Fastlane::UI).not_to receive(:message)
        expect(OpenAI::Client).to receive(:new).with(
          hash_including(request_timeout: 30)
        ).and_return(mock_client)

        described_class.new(params)
      end
    end
  end

  describe '#translate' do
    let(:provider) { described_class.new(valid_params) }

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
    end

    context 'on successful translation' do
      it 'returns translated text' do
        allow(mock_client).to receive(:chat).and_return({
          'choices' => [{ 'message' => { 'content' => 'Hallo Welt' } }]
        })

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to eq('Hallo Welt')
      end

      it 'strips whitespace from response' do
        allow(mock_client).to receive(:chat).and_return({
          'choices' => [{ 'message' => { 'content' => '  Hallo Welt  ' } }]
        })

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to eq('Hallo Welt')
      end

      it 'builds correct prompt with source and target locales' do
        expect(mock_client).to receive(:chat) do |args|
          messages = args[:parameters][:messages]
          content = messages.first[:content]

          expect(content).to include('Translate the following text from en-US to de-DE')
          expect(content).to include('Hello World')

          { 'choices' => [{ 'message' => { 'content' => 'Translated' } }] }
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'uses custom model name when specified' do
        provider = described_class.new(valid_params.merge(model_name: 'gpt-4-turbo'))

        expect(mock_client).to receive(:chat).with(
          hash_including(
            parameters: hash_including(model: 'gpt-4-turbo')
          )
        ).and_return({
          'choices' => [{ 'message' => { 'content' => 'Translated' } }]
        })

        provider.translate('Hello', 'en', 'de')
      end

      it 'uses custom temperature when specified' do
        provider = described_class.new(valid_params.merge(temperature: 0.8))

        expect(mock_client).to receive(:chat).with(
          hash_including(
            parameters: hash_including(temperature: 0.8)
          )
        ).and_return({
          'choices' => [{ 'message' => { 'content' => 'Translated' } }]
        })

        provider.translate('Hello', 'en', 'de')
      end

      it 'includes service_tier when specified' do
        provider = described_class.new(valid_params.merge(service_tier: 'flex'))

        expect(mock_client).to receive(:chat).with(
          hash_including(
            parameters: hash_including(service_tier: 'flex')
          )
        ).and_return({
          'choices' => [{ 'message' => { 'content' => 'Translated' } }]
        })

        provider.translate('Hello', 'en', 'de')
      end

      it 'excludes service_tier when not specified' do
        expect(mock_client).to receive(:chat).with(
          hash_including(
            parameters: hash_excluding(:service_tier)
          )
        ).and_return({
          'choices' => [{ 'message' => { 'content' => 'Translated' } }]
        })

        provider.translate('Hello', 'en', 'de')
      end

      it 'excludes service_tier when only whitespace' do
        provider = described_class.new(valid_params.merge(service_tier: '  '))

        expect(mock_client).to receive(:chat).with(
          hash_including(
            parameters: hash_excluding(:service_tier)
          )
        ).and_return({
          'choices' => [{ 'message' => { 'content' => 'Translated' } }]
        })

        provider.translate('Hello', 'en', 'de')
      end
    end

    context 'with Android platform limitations' do
      let(:android_params) { valid_params.merge(platform: 'android') }
      let(:provider) { described_class.new(android_params) }

      it 'includes Android character limit in prompt' do
        expect(mock_client).to receive(:chat) do |args|
          messages = args[:parameters][:messages]
          content = messages.first[:content]

          expect(content).to include('500 characters')
          expect(content).to include('Google Play Store')

          { 'choices' => [{ 'message' => { 'content' => 'Translated' } }] }
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'with context parameter' do
      let(:context_params) { valid_params.merge(context: 'This is a mobile app update') }
      let(:provider) { described_class.new(context_params) }

      it 'includes context in prompt' do
        expect(mock_client).to receive(:chat) do |args|
          messages = args[:parameters][:messages]
          content = messages.first[:content]

          expect(content).to include('Context: This is a mobile app update')

          { 'choices' => [{ 'message' => { 'content' => 'Translated' } }] }
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'on API error' do
      it 'returns nil on API error' do
        allow(mock_client).to receive(:chat).and_return({
          'error' => { 'message' => 'Rate limit exceeded' }
        })

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'logs error message' do
        allow(mock_client).to receive(:chat).and_return({
          'error' => { 'message' => 'Rate limit exceeded' }
        })

        expect(Fastlane::UI).to receive(:error).with(/OpenAI translation error: Rate limit exceeded/)

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'on exception' do
      it 'returns nil on StandardError' do
        allow(mock_client).to receive(:chat).and_raise(StandardError.new('Network timeout'))

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'logs error message' do
        allow(mock_client).to receive(:chat).and_raise(StandardError.new('Network timeout'))

        expect(Fastlane::UI).to receive(:error).with(/OpenAI provider error: Network timeout/)

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'with empty or nil response' do
      it 'handles empty choices array' do
        allow(mock_client).to receive(:chat).and_return({
          'choices' => []
        })

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'handles missing content' do
        allow(mock_client).to receive(:chat).and_return({
          'choices' => [{ 'message' => {} }]
        })

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end
    end
  end

  describe '#valid?' do
    it 'returns true when no config errors' do
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
      provider = described_class.new(valid_params)
      expect(provider.params).to eq(valid_params)
    end
  end

  describe '#config_errors' do
    it 'returns empty array for valid params' do
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
