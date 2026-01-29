describe Fastlane::Helper::Providers::GeminiProvider do
  let(:valid_params) do
    {
      api_token: 'test-token',
      model_name: 'gemini-2.5-flash',
      temperature: 0.5,
      platform: 'ios'
    }
  end

  let(:mock_http) { instance_double(Net::HTTP) }
  let(:mock_response) { instance_double(Net::HTTPSuccess, body: response_body, code: '200', message: 'OK') }

  let(:response_body) do
    {
      'candidates' => [
        {
          'content' => {
            'parts' => [
              { 'text' => 'Hallo Welt' }
            ]
          }
        }
      ]
    }.to_json
  end

  before do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:error)
  end

  describe '.provider_name' do
    it 'returns gemini' do
      expect(described_class.provider_name).to eq('gemini')
    end
  end

  describe '.display_name' do
    it 'returns Google Gemini' do
      expect(described_class.display_name).to eq('Google Gemini')
    end
  end

  describe '.required_credentials' do
    it 'returns [:api_token]' do
      expect(described_class.required_credentials).to eq([:api_token])
    end
  end

  describe '.optional_params' do
    it 'returns hash with model_name, temperature, and request_timeout' do
      optional = described_class.optional_params

      expect(optional).to have_key(:model_name)
      expect(optional).to have_key(:temperature)
      expect(optional).to have_key(:request_timeout)
    end

    it 'has correct default values' do
      optional = described_class.optional_params

      expect(optional[:model_name][:default]).to eq('gemini-2.5-flash')
      expect(optional[:temperature][:default]).to eq(0.5)
      expect(optional[:request_timeout][:default]).to eq(60)
    end
  end

  describe '#initialize' do
    context 'with valid credentials' do
      it 'creates provider with valid credentials' do
        expect { described_class.new(valid_params) }.not_to raise_error
      end

      it 'sets correct API key' do
        provider = described_class.new(valid_params)
        expect(provider.instance_variable_get(:@api_key)).to eq('test-token')
      end

      it 'uses custom model name when specified' do
        params = valid_params.merge(model_name: 'gemini-2.5-pro')
        provider = described_class.new(params)
        expect(provider.instance_variable_get(:@model)).to eq('gemini-2.5-pro')
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
  end

  describe '#translate' do
    let(:provider) { described_class.new(valid_params) }

    before do
      allow(Net::HTTP).to receive(:new).with('generativelanguage.googleapis.com', 443).and_return(mock_http)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:read_timeout=)
      allow(mock_http).to receive(:request).and_return(mock_response)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end

    context 'on successful translation' do
      it 'returns translated text' do
        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to eq('Hallo Welt')
      end

      it 'strips whitespace from response' do
        response_with_whitespace = {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  { 'text' => '  Hallo Welt  ' }
                ]
              }
            }
          ]
        }.to_json
        allow(mock_response).to receive(:body).and_return(response_with_whitespace)

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to eq('Hallo Welt')
      end

      it 'builds correct prompt with source and target locales' do
        expect(mock_http).to receive(:request) do |request|
          body = JSON.parse(request.body)
          text = body['contents'].first['parts']['text']

          expect(text).to include('Translate the following text from en-US to de-DE')
          expect(text).to include('Hello World')

          mock_response
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end

      it 'uses custom model name when specified' do
        provider = described_class.new(valid_params.merge(model_name: 'gemini-2.5-pro'))
        allow(Net::HTTP).to receive(:new).with('generativelanguage.googleapis.com', 443).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)

        expect(mock_http).to receive(:request) do |request|
          # Check that the model is in the URI path
          expect(request.path).to include('gemini-2.5-pro')
          mock_response
        end

        provider.translate('Hello', 'en', 'de')
      end

      it 'uses custom temperature when specified' do
        provider = described_class.new(valid_params.merge(temperature: 0.8))
        allow(Net::HTTP).to receive(:new).with('generativelanguage.googleapis.com', 443).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)

        expect(mock_http).to receive(:request) do |request|
          body = JSON.parse(request.body)
          expect(body['generationConfig']['temperature']).to eq(0.8)
          mock_response
        end

        provider.translate('Hello', 'en', 'de')
      end

      it 'converts temperature to float' do
        provider = described_class.new(valid_params.merge(temperature: '0.7'))
        allow(Net::HTTP).to receive(:new).with('generativelanguage.googleapis.com', 443).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)

        expect(mock_http).to receive(:request) do |request|
          body = JSON.parse(request.body)
          expect(body['generationConfig']['temperature']).to eq(0.7)
          mock_response
        end

        provider.translate('Hello', 'en', 'de')
      end
    end

    context 'with Android platform limitations' do
      let(:android_params) { valid_params.merge(platform: 'android') }
      let(:provider) { described_class.new(android_params) }

      it 'includes Android character limit in prompt' do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)

        expect(mock_http).to receive(:request) do |request|
          body = JSON.parse(request.body)
          text = body['contents'].first['parts']['text']

          expect(text).to include('500 characters')
          expect(text).to include('Google Play Store')

          mock_response
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'with context parameter' do
      let(:context_params) { valid_params.merge(context: 'This is a mobile app update') }
      let(:provider) { described_class.new(context_params) }

      it 'includes context in prompt' do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)

        expect(mock_http).to receive(:request) do |request|
          body = JSON.parse(request.body)
          text = body['contents'].first['parts']['text']

          expect(text).to include('Context: This is a mobile app update')

          mock_response
        end

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'on error' do
      it 'returns nil on StandardError' do
        allow(mock_http).to receive(:request).and_raise(StandardError.new('API error'))

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'logs error message' do
        allow(mock_http).to receive(:request).and_raise(StandardError.new('API error'))

        expect(Fastlane::UI).to receive(:error).with(/Gemini provider error: API error/)

        provider.translate('Hello World', 'en-US', 'de-DE')
      end
    end

    context 'with empty or nil response' do
      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)
      end

      it 'handles empty candidates array' do
        allow(mock_http).to receive(:request).and_return(
          instance_double(Net::HTTPSuccess, body: { 'candidates' => [] }.to_json, code: '200', message: 'OK', is_a?: true)
        )
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'handles missing content' do
        response = instance_double(Net::HTTPSuccess, body: { 'candidates' => [{}] }.to_json, code: '200', message: 'OK')
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_http).to receive(:request).and_return(response)

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'handles missing parts' do
        response = instance_double(Net::HTTPSuccess, body: { 'candidates' => [{ 'content' => {} }] }.to_json, code: '200', message: 'OK')
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_http).to receive(:request).and_return(response)

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end

      it 'handles missing text' do
        response = instance_double(Net::HTTPSuccess, body: { 'candidates' => [{ 'content' => { 'parts' => [{}] } }] }.to_json, code: '200', message: 'OK')
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_http).to receive(:request).and_return(response)

        result = provider.translate('Hello World', 'en-US', 'de-DE')
        expect(result).to be_nil
      end
    end

    context 'with default values' do
      let(:minimal_params) { { api_token: 'test-token' } }
      let(:provider) { described_class.new(minimal_params) }

      before do
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:read_timeout=)
      end

      it 'uses default model when not specified' do
        expect(mock_http).to receive(:request) do |request|
          expect(request.path).to include('gemini-2.5-flash')
          mock_response
        end

        provider.translate('Hello', 'en', 'de')
      end

      it 'uses default temperature when not specified' do
        expect(mock_http).to receive(:request) do |request|
          body = JSON.parse(request.body)
          expect(body['generationConfig']['temperature']).to eq(0.5)
          mock_response
        end

        provider.translate('Hello', 'en', 'de')
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
