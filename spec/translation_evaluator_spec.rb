describe Fastlane::Helper::TranslationEvaluator do
  let(:params) { { typesafe_api_key: 'test-typesafe-key' } }
  let(:evaluator) { described_class.new(params) }
  let(:http) { instance_double(Net::HTTP) }
  let(:body) do
    {
      'model' => 'jev-1.13.0',
      'answers' => described_class::QUESTIONS.keys.each_with_object({}) do |name, answers|
        answers[name] = { 'type' => 'noul', 'noul' => 0.1 }
      end
    }
  end

  def response(code, body = nil)
    klass = Net::HTTPResponse::CODE_TO_OBJ[code] || Net::HTTPServerError
    result = klass.new('1.1', code, 'test response')
    allow(result).to receive(:body).and_return(JSON.generate(body)) if body
    result
  end

  def evaluate
    evaluator.evaluate('Saved Recipes work offline.', 'Recettes enregistrées disponibles hors ligne.', 'en-US', 'fr-FR',
                       glossary_terms: { 'Saved Recipes' => 'Recettes enregistrées' }, platform: 'android')
  end

  before do
    allow(Net::HTTP).to receive(:new).with('api.typesafe.ai', 443).and_return(http)
    allow(http).to receive(:use_ssl=).with(true)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:write_timeout=)
  end

  it 'sends all five questions in one authenticated request with relevant state' do
    expect(http).to receive(:request) do |request|
      expect(request.path).to eq('/v1/systemone')
      expect(request['Authorization']).to eq('Bearer test-typesafe-key')
      payload = JSON.parse(request.body)
      expect(payload['model']).to eq('jev-1.13.0')
      expect(payload['questions'].keys).to match_array(described_class::QUESTIONS.keys)
      expect(payload['questions'].values.map { |q| q['type'] }.uniq).to eq(['noul'])
      expect(payload['state']).to include(
        'source' => 'Saved Recipes work offline.',
        'translation' => 'Recettes enregistrées disponibles hors ligne.',
        'source_locale' => 'en-US', 'target_locale' => 'fr-FR',
        'glossary' => { 'Saved Recipes' => 'Recettes enregistrées' }, 'platform' => 'android'
      )
      expect(payload['state']['policy']).to include('Summarize concisely')
      response('200', body)
    end

    expect(evaluate).to include(status: 'checked', model: 'jev-1.13.0', warnings: {})
  end

  it 'reports every defect at or above the threshold with its original probability' do
    body['answers']['added_claim']['noul'] = 0.5
    body['answers']['omission']['noul'] = 0.8
    allow(http).to receive(:request).and_return(response('200', body))

    result = evaluate
    expect(result[:warnings]).to eq('added_claim' => 0.5, 'omission' => 0.8)
    expect(result[:probabilities].size).to eq(5)
  end

  it 'honors a custom threshold, model and timeouts' do
    params.merge!(jev_threshold: 0.8, jev_model: 'jev-latest', jev_timeout: 3)
    body['answers']['omission']['noul'] = 0.7
    %i[open_timeout= read_timeout= write_timeout=].each do |setter|
      expect(http).to receive(setter).with(3)
    end
    expect(http).to receive(:request) do |request|
      expect(JSON.parse(request.body)['model']).to eq('jev-latest')
      response('200', body)
    end
    expect(evaluate[:warnings]).to eq({})
  end

  it 'reads the API key from the environment when no parameter is provided' do
    params.clear
    allow(ENV).to receive(:[]).with('TYPESAFE_API_KEY').and_return('environment-key')
    expect(http).to receive(:request) do |request|
      expect(request['Authorization']).to eq('Bearer environment-key')
      response('200', body)
    end
    expect(evaluate[:status]).to eq('checked')
  end

  it 'does not contact the API when the key is missing' do
    params.clear
    allow(ENV).to receive(:[]).with('TYPESAFE_API_KEY').and_return(nil)
    expect(Net::HTTP).not_to receive(:new)
    expect(evaluate).to eq(status: 'unavailable', error: 'TYPESAFE_API_KEY is not configured')
  end

  %w[429 529].each do |code|
    it "retries HTTP #{code} with bounded backoff" do
      expect(http).to receive(:request).exactly(3).times.and_return(response(code), response(code), response('200', body))
      expect(evaluator).to receive(:sleep).with(0.5).ordered
      expect(evaluator).to receive(:sleep).with(1.0).ordered
      expect(evaluate[:status]).to eq('checked')
    end
  end

  it 'ends the check instead of retrying before a long Retry-After delay' do
    limited = response('429')
    limited['Retry-After'] = '120'
    expect(http).to receive(:request).once.and_return(limited)
    expect(evaluator).not_to receive(:sleep)
    expect(evaluate).to eq(status: 'unavailable', error: 'HTTP 429')
  end

  it 'stops after two retries when the API remains overloaded' do
    expect(http).to receive(:request).exactly(3).times.and_return(response('529'))
    expect(evaluator).to receive(:sleep).with(0.5).ordered
    expect(evaluator).to receive(:sleep).with(1.0).ordered
    expect(evaluate).to eq(status: 'unavailable', error: 'HTTP 529')
  end

  it 'honors a short Retry-After delay' do
    limited = response('429')
    limited['Retry-After'] = '1.5'
    expect(http).to receive(:request).twice.and_return(limited, response('200', body))
    expect(evaluator).to receive(:sleep).with(1.5)
    expect(evaluate[:status]).to eq('checked')
  end

  it 'falls back to the environment when an explicit key is blank, stripping whitespace' do
    params[:typesafe_api_key] = '  '
    allow(ENV).to receive(:[]).with('TYPESAFE_API_KEY').and_return(' environment-key ')
    expect(http).to receive(:request) do |request|
      expect(request['Authorization']).to eq('Bearer environment-key')
      response('200', body)
    end
    expect(evaluate[:status]).to eq('checked')
  end

  it 'does not retry or expose API error bodies on authentication failure' do
    expect(http).to receive(:request).once.and_return(response('401', { error: 'test-typesafe-key' }))
    expect(evaluator).not_to receive(:sleep)
    expect(evaluate).to eq(status: 'unavailable', error: 'HTTP 401')
  end

  it 'keeps exception messages out of results' do
    allow(http).to receive(:request).and_raise(Net::ReadTimeout, 'test-typesafe-key source text')
    expect(evaluate).to eq(status: 'unavailable', error: 'request failed (Net::ReadTimeout)')
  end

  it 'handles invalid JSON without exposing response contents' do
    bad = response('200')
    allow(bad).to receive(:body).and_return('test-typesafe-key invalid JSON')
    allow(http).to receive(:request).and_return(bad)
    expect(evaluate).to eq(status: 'unavailable', error: 'request failed (JSON::ParserError)')
  end

  [nil, [], {}, { 'model' => 'jev-1.13.0', 'answers' => [] }].each do |invalid|
    it "rejects an invalid top-level response: #{invalid.inspect}" do
      ok = response('200')
      allow(ok).to receive(:body).and_return(JSON.generate(invalid))
      allow(http).to receive(:request).and_return(ok)
      expect(evaluate).to eq(status: 'unavailable', error: 'invalid response')
    end
  end

  [-0.1, 1.1, '0.9', nil, true].each do |invalid|
    it "rejects invalid probabilities: #{invalid.inspect}" do
      body['answers']['omission']['noul'] = invalid
      allow(http).to receive(:request).and_return(response('200', body))
      expect(evaluate).to eq(status: 'unavailable', error: 'invalid response')
    end
  end

  it 'rejects missing answers rather than reporting a partial check as successful' do
    body['answers'].delete('contradiction')
    allow(http).to receive(:request).and_return(response('200', body))
    expect(evaluate).to eq(status: 'unavailable', error: 'invalid response')
  end

  it 'rejects the wrong question type' do
    body['answers']['omission']['type'] = 'score'
    allow(http).to receive(:request).and_return(response('200', body))
    expect(evaluate[:status]).to eq('unavailable')
  end
end
