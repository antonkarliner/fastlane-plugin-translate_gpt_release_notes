require 'spec_helper'
require 'openai'
require 'anthropic'
require 'deepl'

# Contract tests: verify the real SDKs still expose the API surface our
# providers call. If a gem upgrade removes or renames these, these tests fail
# loudly instead of the providers silently breaking at runtime.
describe 'Provider/SDK contracts' do
  describe 'OpenAI' do
    it 'OpenAI::Client responds to #chat' do
      expect(OpenAI::Client.instance_methods).to include(:chat)
    end
  end

  describe 'Anthropic' do
    it 'Anthropic::Client exposes a #messages resource' do
      expect(Anthropic::Client.instance_methods).to include(:messages)
    end

    it 'the messages resource implements #create' do
      expect(Anthropic::Resources::Messages.instance_methods).to include(:create)
    end

    it 'does NOT rely on the removed legacy #complete client method' do
      # Guards against regressing to the legacy Text-Completions call.
      expect(Anthropic::Client.instance_methods).not_to include(:complete)
    end
  end

  describe 'DeepL' do
    it 'DeepL responds to .translate' do
      expect(DeepL).to respond_to(:translate)
    end
  end
end
