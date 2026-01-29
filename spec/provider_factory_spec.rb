describe Fastlane::Helper::Providers::ProviderFactory do
  # Helper method to clear all related environment variables
  def clear_env_vars
    %w[OPENAI_API_KEY GPT_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY DEEPL_API_KEY].each do |var|
      ENV.delete(var)
    end
  end

  before do
    clear_env_vars
    allow(Fastlane::UI).to receive(:user_error!)
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:error)
  end

  after do
    clear_env_vars
  end

  describe '.create' do
    context 'creating openai provider' do
      it 'creates OpenAIProvider instance with valid credentials' do
        ENV['OPENAI_API_KEY'] = 'test-openai-key'

        provider = described_class.create('openai', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::OpenAIProvider)
        expect(provider).to be_valid
      end

      it 'creates provider with additional params' do
        ENV['OPENAI_API_KEY'] = 'test-openai-key'
        params = { model_name: 'gpt-4', temperature: 0.7 }

        provider = described_class.create('openai', params)

        expect(provider.params[:model_name]).to eq('gpt-4')
        expect(provider.params[:temperature]).to eq(0.7)
      end

      it 'uses credentials from params over env vars' do
        ENV['OPENAI_API_KEY'] = 'env-key'
        params = { openai_api_key: 'param-key' }

        provider = described_class.create('openai', params)

        expect(provider.params[:api_token]).to eq('param-key')
      end
    end

    context 'creating anthropic provider' do
      it 'creates AnthropicProvider instance with valid credentials' do
        ENV['ANTHROPIC_API_KEY'] = 'test-anthropic-key'

        provider = described_class.create('anthropic', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::AnthropicProvider)
        expect(provider).to be_valid
      end
    end

    context 'creating gemini provider' do
      it 'creates GeminiProvider instance with valid credentials' do
        ENV['GEMINI_API_KEY'] = 'test-gemini-key'

        provider = described_class.create('gemini', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::GeminiProvider)
        expect(provider).to be_valid
      end
    end

    context 'creating deepl provider' do
      it 'creates DeepLProvider instance with valid credentials' do
        ENV['DEEPL_API_KEY'] = 'test-deepl-key'

        provider = described_class.create('deepl', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::DeepLProvider)
        expect(provider).to be_valid
      end
    end

    context 'with default provider' do
      it 'defaults to openai when provider_name is nil' do
        ENV['OPENAI_API_KEY'] = 'test-openai-key'

        provider = described_class.create(nil, {})

        expect(provider).to be_a(Fastlane::Helper::Providers::OpenAIProvider)
      end

      it 'defaults to openai when provider_name is empty string' do
        ENV['OPENAI_API_KEY'] = 'test-openai-key'

        provider = described_class.create('', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::OpenAIProvider)
      end
    end

    context 'with case insensitive provider names' do
      before do
        ENV['OPENAI_API_KEY'] = 'test-openai-key'
      end

      it 'handles uppercase provider names' do
        provider = described_class.create('OPENAI', {})
        expect(provider).to be_a(Fastlane::Helper::Providers::OpenAIProvider)
      end

      it 'handles mixed case provider names' do
        provider = described_class.create('OpEnAi', {})
        expect(provider).to be_a(Fastlane::Helper::Providers::OpenAIProvider)
      end
    end

    context 'error handling' do
      it 'raises error for unknown provider' do
        expect(Fastlane::UI).to receive(:user_error!).with(/Unknown provider 'unknown'/)

        described_class.create('unknown', {})
      end

      it 'raises error when API key is missing' do
        expect(Fastlane::UI).to receive(:user_error!).with(/No API key found for provider 'openai'/)

        described_class.create('openai', {})
      end

      it 'includes available providers in error message for unknown provider' do
        expect(Fastlane::UI).to receive(:user_error!).with(/Available: openai, anthropic, gemini, deepl/)

        described_class.create('unknown', {})
      end

      it 'includes credential help in error message for missing key' do
        expect(Fastlane::UI).to receive(:user_error!).with(/Set OPENAI_API_KEY.*or pass :openai_api_key/)

        described_class.create('openai', {})
      end
    end
  end

  describe '.create_with_key' do
    context 'creating providers with explicit API key' do
      it 'creates OpenAIProvider with explicit key' do
        provider = described_class.create_with_key('openai', 'explicit-key', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::OpenAIProvider)
        expect(provider.params[:api_token]).to eq('explicit-key')
      end

      it 'creates AnthropicProvider with explicit key' do
        provider = described_class.create_with_key('anthropic', 'explicit-key', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::AnthropicProvider)
        expect(provider.params[:api_token]).to eq('explicit-key')
      end

      it 'creates GeminiProvider with explicit key' do
        provider = described_class.create_with_key('gemini', 'explicit-key', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::GeminiProvider)
        expect(provider.params[:api_token]).to eq('explicit-key')
      end

      it 'creates DeepLProvider with explicit key' do
        provider = described_class.create_with_key('deepl', 'explicit-key', {})

        expect(provider).to be_a(Fastlane::Helper::Providers::DeepLProvider)
        expect(provider.params[:api_token]).to eq('explicit-key')
      end
    end

    context 'with additional params' do
      it 'merges additional params with api_token' do
        params = { model_name: 'gpt-4', platform: 'ios' }

        provider = described_class.create_with_key('openai', 'explicit-key', params)

        expect(provider.params[:api_token]).to eq('explicit-key')
        expect(provider.params[:model_name]).to eq('gpt-4')
        expect(provider.params[:platform]).to eq('ios')
      end

      it 'explicit api_token overrides any in params' do
        params = { api_token: 'from-params', model_name: 'gpt-4' }

        provider = described_class.create_with_key('openai', 'explicit-key', params)

        expect(provider.params[:api_token]).to eq('explicit-key')
      end
    end

    context 'with case insensitive provider names' do
      it 'handles uppercase provider names' do
        provider = described_class.create_with_key('OPENAI', 'explicit-key', {})
        expect(provider).to be_a(Fastlane::Helper::Providers::OpenAIProvider)
      end

      it 'handles mixed case provider names' do
        provider = described_class.create_with_key('AnThRoPiC', 'explicit-key', {})
        expect(provider).to be_a(Fastlane::Helper::Providers::AnthropicProvider)
      end
    end

    context 'error handling' do
      it 'raises error for unknown provider' do
        expect(Fastlane::UI).to receive(:user_error!).with("Unknown provider 'unknown'")

        described_class.create_with_key('unknown', 'key', {})
      end

      it 'allows nil/empty api_key (validation happens in provider)' do
        # The provider itself handles validation of empty keys
        provider = described_class.create_with_key('openai', '', {})
        expect(provider).to be_a(Fastlane::Helper::Providers::OpenAIProvider)
        expect(provider).not_to be_valid
      end
    end
  end

  describe '.available_provider_names' do
    it 'returns array of all provider names' do
      names = described_class.available_provider_names

      expect(names).to contain_exactly('openai', 'anthropic', 'gemini', 'deepl')
    end

    it 'returns frozen array' do
      names = described_class.available_provider_names
      expect(names).to be_frozen
    end
  end

  describe '.valid_provider?' do
    it 'returns true for valid provider names' do
      expect(described_class.valid_provider?('openai')).to be true
      expect(described_class.valid_provider?('anthropic')).to be true
      expect(described_class.valid_provider?('gemini')).to be true
      expect(described_class.valid_provider?('deepl')).to be true
    end

    it 'returns false for invalid provider names' do
      expect(described_class.valid_provider?('unknown')).to be false
      expect(described_class.valid_provider?('')).to be false
    end

    it 'returns false for nil provider name' do
      expect(described_class.valid_provider?(nil)).to be false
    end

    context 'with case insensitive provider names' do
      it 'handles uppercase provider names' do
        expect(described_class.valid_provider?('OPENAI')).to be true
        expect(described_class.valid_provider?('ANTHROPIC')).to be true
      end

      it 'handles mixed case provider names' do
        expect(described_class.valid_provider?('OpEnAi')).to be true
        expect(described_class.valid_provider?('GeMiNi')).to be true
      end
    end
  end

  describe '.provider_config' do
    context 'for openai provider' do
      it 'returns complete configuration' do
        config = described_class.provider_config('openai')

        expect(config[:name]).to eq('openai')
        expect(config[:display_name]).to eq('OpenAI GPT')
        expect(config[:required_credentials]).to eq([:api_token])
        expect(config[:optional_params]).to include(:model_name, :temperature, :service_tier, :request_timeout)
        expect(config[:credential_help]).to include('OPENAI_API_KEY')
      end
    end

    context 'for anthropic provider' do
      it 'returns complete configuration' do
        config = described_class.provider_config('anthropic')

        expect(config[:name]).to eq('anthropic')
        expect(config[:display_name]).to eq('Anthropic Claude')
        expect(config[:required_credentials]).to eq([:api_token])
        expect(config[:optional_params]).to include(:model_name, :max_tokens, :temperature, :request_timeout)
        expect(config[:credential_help]).to include('ANTHROPIC_API_KEY')
      end
    end

    context 'for gemini provider' do
      it 'returns complete configuration' do
        config = described_class.provider_config('gemini')

        expect(config[:name]).to eq('gemini')
        expect(config[:display_name]).to eq('Google Gemini')
        expect(config[:required_credentials]).to eq([:api_token])
        expect(config[:optional_params]).to include(:model_name, :temperature, :request_timeout)
        expect(config[:credential_help]).to include('GEMINI_API_KEY')
      end
    end

    context 'for deepl provider' do
      it 'returns complete configuration' do
        config = described_class.provider_config('deepl')

        expect(config[:name]).to eq('deepl')
        expect(config[:display_name]).to eq('DeepL')
        expect(config[:required_credentials]).to eq([:api_token])
        expect(config[:optional_params]).to include(:request_timeout, :formality)
        expect(config[:credential_help]).to include('DEEPL_API_KEY')
      end
    end

    context 'with case insensitive provider names' do
      it 'handles uppercase provider names' do
        config = described_class.provider_config('OPENAI')
        expect(config[:name]).to eq('openai')
      end

      it 'handles mixed case provider names' do
        config = described_class.provider_config('AnThRoPiC')
        expect(config[:name]).to eq('anthropic')
      end
    end

    context 'for unknown provider' do
      it 'returns empty hash' do
        config = described_class.provider_config('unknown')
        expect(config).to eq({})
      end

      it 'returns empty hash for nil provider' do
        config = described_class.provider_config(nil)
        expect(config).to eq({})
      end
    end
  end

  describe '.provider_display_names' do
    it 'returns hash mapping provider names to display names' do
      display_names = described_class.provider_display_names

      expect(display_names).to eq({
        'openai' => 'OpenAI GPT',
        'anthropic' => 'Anthropic Claude',
        'gemini' => 'Google Gemini',
        'deepl' => 'DeepL'
      })
    end
  end
end
