describe Fastlane::Helper::CredentialResolver do
  # Helper method to clear all related environment variables
  def clear_env_vars
    %w[OPENAI_API_KEY GPT_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY DEEPL_API_KEY].each do |var|
      ENV.delete(var)
    end
  end

  # Helper method to set environment variables
  def set_env_var(key, value)
    ENV[key] = value
  end

  before do
    clear_env_vars
  end

  after do
    clear_env_vars
  end

  describe '.resolve' do
    context 'for openai provider' do
      let(:provider) { 'openai' }

      it 'returns parameter value when provided' do
        params = { openai_api_key: 'param-key' }
        expect(described_class.resolve(provider, params)).to eq('param-key')
      end

      it 'returns OPENAI_API_KEY env var when no param provided' do
        set_env_var('OPENAI_API_KEY', 'env-key')
        expect(described_class.resolve(provider, {})).to eq('env-key')
      end

      it 'returns GPT_API_KEY env var as legacy fallback' do
        set_env_var('GPT_API_KEY', 'legacy-key')
        expect(described_class.resolve(provider, {})).to eq('legacy-key')
      end

      it 'prefers OPENAI_API_KEY over GPT_API_KEY' do
        set_env_var('OPENAI_API_KEY', 'new-key')
        set_env_var('GPT_API_KEY', 'old-key')
        expect(described_class.resolve(provider, {})).to eq('new-key')
      end

      it 'strips whitespace from parameter values' do
        params = { openai_api_key: '  spaced-key  ' }
        expect(described_class.resolve(provider, params)).to eq('spaced-key')
      end

      it 'strips whitespace from environment variables' do
        set_env_var('OPENAI_API_KEY', '  env-key  ')
        expect(described_class.resolve(provider, {})).to eq('env-key')
      end

      it 'returns nil when no credentials exist' do
        expect(described_class.resolve(provider, {})).to be_nil
      end

      it 'returns nil for empty parameter value' do
        params = { openai_api_key: '' }
        expect(described_class.resolve(provider, params)).to be_nil
      end

      it 'returns nil for whitespace-only parameter value' do
        params = { openai_api_key: '   ' }
        expect(described_class.resolve(provider, params)).to be_nil
      end
    end

    context 'for anthropic provider' do
      let(:provider) { 'anthropic' }

      it 'returns parameter value when provided' do
        params = { anthropic_api_key: 'param-key' }
        expect(described_class.resolve(provider, params)).to eq('param-key')
      end

      it 'returns ANTHROPIC_API_KEY env var when no param provided' do
        set_env_var('ANTHROPIC_API_KEY', 'env-key')
        expect(described_class.resolve(provider, {})).to eq('env-key')
      end

      it 'returns nil when no credentials exist' do
        expect(described_class.resolve(provider, {})).to be_nil
      end
    end

    context 'for gemini provider' do
      let(:provider) { 'gemini' }

      it 'returns parameter value when provided' do
        params = { gemini_api_key: 'param-key' }
        expect(described_class.resolve(provider, params)).to eq('param-key')
      end

      it 'returns GEMINI_API_KEY env var when no param provided' do
        set_env_var('GEMINI_API_KEY', 'env-key')
        expect(described_class.resolve(provider, {})).to eq('env-key')
      end

      it 'returns nil when no credentials exist' do
        expect(described_class.resolve(provider, {})).to be_nil
      end
    end

    context 'for deepl provider' do
      let(:provider) { 'deepl' }

      it 'returns parameter value when provided' do
        params = { deepl_api_key: 'param-key' }
        expect(described_class.resolve(provider, params)).to eq('param-key')
      end

      it 'returns DEEPL_API_KEY env var when no param provided' do
        set_env_var('DEEPL_API_KEY', 'env-key')
        expect(described_class.resolve(provider, {})).to eq('env-key')
      end

      it 'returns nil when no credentials exist' do
        expect(described_class.resolve(provider, {})).to be_nil
      end
    end

    context 'with case insensitive provider names' do
      it 'handles uppercase provider names' do
        params = { openai_api_key: 'test-key' }
        expect(described_class.resolve('OPENAI', params)).to eq('test-key')
      end

      it 'handles mixed case provider names' do
        params = { anthropic_api_key: 'test-key' }
        expect(described_class.resolve('AnThrOpIc', params)).to eq('test-key')
      end

      it 'handles mixed case for gemini' do
        set_env_var('GEMINI_API_KEY', 'test-key')
        expect(described_class.resolve('GemIni', {})).to eq('test-key')
      end

      it 'handles mixed case for deepl' do
        set_env_var('DEEPL_API_KEY', 'test-key')
        expect(described_class.resolve('DeepL', {})).to eq('test-key')
      end
    end

    context 'with nil or invalid provider names' do
      it 'returns nil for nil provider name' do
        params = { openai_api_key: 'test-key' }
        expect(described_class.resolve(nil, params)).to be_nil
      end

      it 'returns nil for unknown provider name' do
        expect(described_class.resolve('unknown', {})).to be_nil
      end

      it 'returns nil for empty string provider name' do
        expect(described_class.resolve('', {})).to be_nil
      end
    end

    context 'priority resolution' do
      let(:provider) { 'openai' }

      it 'follows priority: param > env var > legacy' do
        set_env_var('OPENAI_API_KEY', 'env-key')
        set_env_var('GPT_API_KEY', 'legacy-key')
        params = { openai_api_key: 'param-key' }

        expect(described_class.resolve(provider, params)).to eq('param-key')
      end

      it 'uses env var when param is empty' do
        set_env_var('OPENAI_API_KEY', 'env-key')
        params = { openai_api_key: '' }

        expect(described_class.resolve(provider, params)).to eq('env-key')
      end

      it 'uses legacy when primary env var is empty but legacy exists' do
        set_env_var('OPENAI_API_KEY', '')
        set_env_var('GPT_API_KEY', 'legacy-key')

        expect(described_class.resolve(provider, {})).to eq('legacy-key')
      end
    end
  end

  describe '.credentials_exist?' do
    context 'for each provider' do
      it 'returns true when openai credentials exist via param' do
        params = { openai_api_key: 'test-key' }
        expect(described_class.credentials_exist?('openai', params)).to be true
      end

      it 'returns true when openai credentials exist via env var' do
        set_env_var('OPENAI_API_KEY', 'test-key')
        expect(described_class.credentials_exist?('openai', {})).to be true
      end

      it 'returns false when openai credentials do not exist' do
        expect(described_class.credentials_exist?('openai', {})).to be false
      end

      it 'returns true when anthropic credentials exist' do
        set_env_var('ANTHROPIC_API_KEY', 'test-key')
        expect(described_class.credentials_exist?('anthropic', {})).to be true
      end

      it 'returns false when anthropic credentials do not exist' do
        expect(described_class.credentials_exist?('anthropic', {})).to be false
      end

      it 'returns true when gemini credentials exist' do
        set_env_var('GEMINI_API_KEY', 'test-key')
        expect(described_class.credentials_exist?('gemini', {})).to be true
      end

      it 'returns false when gemini credentials do not exist' do
        expect(described_class.credentials_exist?('gemini', {})).to be false
      end

      it 'returns true when deepl credentials exist' do
        set_env_var('DEEPL_API_KEY', 'test-key')
        expect(described_class.credentials_exist?('deepl', {})).to be true
      end

      it 'returns false when deepl credentials do not exist' do
        expect(described_class.credentials_exist?('deepl', {})).to be false
      end
    end

    context 'with case insensitive provider names' do
      it 'handles uppercase provider names' do
        set_env_var('OPENAI_API_KEY', 'test-key')
        expect(described_class.credentials_exist?('OPENAI', {})).to be true
      end

      it 'handles mixed case provider names' do
        set_env_var('ANTHROPIC_API_KEY', 'test-key')
        expect(described_class.credentials_exist?('AnThrOpIc', {})).to be true
      end
    end

    context 'with empty or whitespace-only credentials' do
      it 'returns false for empty string credentials' do
        params = { openai_api_key: '' }
        expect(described_class.credentials_exist?('openai', params)).to be false
      end

      it 'returns false for whitespace-only credentials' do
        params = { openai_api_key: '   ' }
        expect(described_class.credentials_exist?('openai', params)).to be false
      end

      it 'returns false for empty env var' do
        set_env_var('OPENAI_API_KEY', '')
        expect(described_class.credentials_exist?('openai', {})).to be false
      end
    end
  end

  describe '.available_providers' do
    it 'returns empty array when no providers have credentials' do
      expect(described_class.available_providers({})).to be_empty
    end

    it 'returns array with single provider when only one has credentials' do
      set_env_var('OPENAI_API_KEY', 'test-key')
      expect(described_class.available_providers({})).to eq(['openai'])
    end

    it 'returns array with multiple providers when multiple have credentials' do
      set_env_var('OPENAI_API_KEY', 'test-key')
      set_env_var('ANTHROPIC_API_KEY', 'test-key')
      set_env_var('GEMINI_API_KEY', 'test-key')

      available = described_class.available_providers({})
      expect(available).to contain_exactly('openai', 'anthropic', 'gemini')
    end

    it 'returns all providers when all have credentials' do
      set_env_var('OPENAI_API_KEY', 'test-key')
      set_env_var('ANTHROPIC_API_KEY', 'test-key')
      set_env_var('GEMINI_API_KEY', 'test-key')
      set_env_var('DEEPL_API_KEY', 'test-key')

      available = described_class.available_providers({})
      expect(available).to contain_exactly('openai', 'anthropic', 'gemini', 'deepl')
    end

    it 'includes providers with credentials via params' do
      params = { openai_api_key: 'test-key', gemini_api_key: 'test-key' }
      available = described_class.available_providers(params)
      expect(available).to contain_exactly('openai', 'gemini')
    end

    it 'combines env vars and params correctly' do
      set_env_var('ANTHROPIC_API_KEY', 'test-key')
      params = { openai_api_key: 'test-key' }

      available = described_class.available_providers(params)
      expect(available).to contain_exactly('openai', 'anthropic')
    end

    it 'does not include providers with only whitespace credentials' do
      params = { openai_api_key: '   ' }
      expect(described_class.available_providers(params)).to be_empty
    end
  end

  describe '.credential_help' do
    context 'for openai provider' do
      it 'returns helpful text for openai' do
        help = described_class.credential_help('openai')
        expect(help).to include('OPENAI_API_KEY')
        expect(help).to include('GPT_API_KEY')
        expect(help).to include(':openai_api_key')
      end
    end

    context 'for anthropic provider' do
      it 'returns helpful text for anthropic' do
        help = described_class.credential_help('anthropic')
        expect(help).to include('ANTHROPIC_API_KEY')
        expect(help).to include(':anthropic_api_key')
      end
    end

    context 'for gemini provider' do
      it 'returns helpful text for gemini' do
        help = described_class.credential_help('gemini')
        expect(help).to include('GEMINI_API_KEY')
        expect(help).to include(':gemini_api_key')
      end
    end

    context 'for deepl provider' do
      it 'returns helpful text for deepl' do
        help = described_class.credential_help('deepl')
        expect(help).to include('DEEPL_API_KEY')
        expect(help).to include(':deepl_api_key')
      end
    end

    context 'with case insensitive provider names' do
      it 'handles uppercase provider names' do
        help = described_class.credential_help('OPENAI')
        expect(help).to include('OPENAI_API_KEY')
      end

      it 'handles mixed case provider names' do
        help = described_class.credential_help('AnThrOpIc')
        expect(help).to include('ANTHROPIC_API_KEY')
      end
    end

    context 'for unknown provider' do
      it 'returns error message for unknown provider' do
        help = described_class.credential_help('unknown')
        expect(help).to eq('Unknown provider: unknown')
      end
    end

    context 'for nil provider' do
      it 'returns error message for nil provider' do
        help = described_class.credential_help(nil)
        expect(help).to eq('Unknown provider: ')
      end
    end
  end

  describe '.all_providers' do
    it 'returns array of all supported provider names' do
      all = described_class.all_providers
      expect(all).to contain_exactly('openai', 'anthropic', 'gemini', 'deepl')
    end

    it 'returns frozen array' do
      all = described_class.all_providers
      expect(all).to be_frozen
    end
  end
end
