# Plan 001: Anthropic provider works against the real `anthropic` 1.x SDK

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 0ce8cd9..HEAD -- lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb spec/providers/anthropic_provider_spec.rb`
> If either in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `0ce8cd9`, 2026-06-15

## Why this matters

The Anthropic Claude provider — one of the four advertised providers and the one the README rates highest for quality — **does not work at all**. It calls `@client.complete(...)` using the legacy Text-Completions API (`max_tokens_to_sample`, a `"\n\nHuman: … Assistant:"` prompt, and `response['completion']`). The gem pinned in the gemspec (`anthropic ~> 1.16`, locked at 1.17.0) is the **official Anthropic Ruby SDK**, whose `Anthropic::Client` has **no `#complete` method** — it exposes `client.messages` and `client.completions` resource objects instead. At runtime every translation raises `NoMethodError: undefined method 'complete'`, which is swallowed by the `rescue StandardError` and returns `nil`. Worse, that `nil` then overwrites the user's localized files (see plan 003). The unit tests pass only because they mock the nonexistent `.complete` method. This plan migrates the provider to the Messages API (`client.messages.create`) and rewrites the spec to mock the method that actually exists.

## Current state

- `lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb` — the broken provider. Relevant excerpt (lines 84–117):

```ruby
def translate(text, source_locale, target_locale, glossary_terms: {})
  # Build prompt using inherited method (includes instructions, glossary, and text)
  prompt = build_prompt(
    text, source_locale, target_locale,
    glossary_terms: glossary_terms,
    platform: @params[:platform]
  )

  # Make API call using ruby-anthropic gem API
  response = @client.complete(
    model: @params[:model_name] || DEFAULT_MODEL,
    max_tokens_to_sample: (@params[:max_tokens] || DEFAULT_MAX_TOKENS).to_i,
    temperature: (@params[:temperature] || DEFAULT_TEMPERATURE).to_f,
    prompt: "\n\nHuman: #{prompt}\n\nAssistant:"
  )

  # Extract text from response
  enforce_android_limit(extract_text_from_response(response))
rescue StandardError => e
  UI.error "Anthropic provider error: #{e.message}"
  nil
end

private

def extract_text_from_response(response)
  return nil if response.nil?

  response['completion']&.strip
end
```

- The `initialize` (lines 59–67) is **correct and must not change** — `Anthropic::Client.new(api_key:, timeout:)` is valid for the 1.x SDK (verified: `client.rb` `initialize(api_key:, …, timeout:)`):

```ruby
def initialize(params)
  super

  timeout = @params[:request_timeout] || DEFAULT_TIMEOUT
  @client = Anthropic::Client.new(
    api_key: credential(:api_token),
    timeout: timeout.to_i
  )
end
```

- `spec/providers/anthropic_provider_spec.rb` — currently mocks `mock_client.receive(:complete)` and asserts `max_tokens_to_sample` / `response['completion']`. All of this is fictional and must be rewritten.

### The real SDK API (verified against `anthropic-1.17.0`)

- Method: `client.messages.create(...)`. `client.messages` returns an `Anthropic::Resources::Messages` instance whose `#create(params)` accepts a single keyword/hash of params.
- Accepted params (from the `create` overload doc): `max_tokens:`, `messages:`, `model:`, `system_:` (note the **trailing underscore**), `temperature:`, and others.
- `messages:` is an array of `{ role: "user", content: "<text>" }` hashes.
- `system_:` is a string — use it for the instruction block (the same content `build_system_instruction` already produces for OpenAI).
- Return value is an `Anthropic::Models::Message` object (NOT a hash). Its `.content` is an **array of typed content blocks**. Text blocks are `Anthropic::Models::TextBlock` with `.type == :text` and a `.text` String. Extract with:

```ruby
response.content
        .select { |block| block.respond_to?(:text) && block.type == :text }
        .map(&:text)
        .join
        .strip
```

### Conventions to match

- The other working AI provider, OpenAI, splits instructions (system) from the text (user). Anthropic's Messages API supports the same split, so use `build_system_instruction` for `system_:` and put the raw `text` in the user message — mirroring `openai_provider.rb:83-100`. Do **not** keep using `build_prompt` (the single-blob prompt) once you move to Messages; `build_system_instruction` is the right helper here.
- `build_system_instruction(source_locale, target_locale, glossary_terms:, platform:)` is defined in `base_provider.rb:139-165` and already handles instructions, Android limit, context, and glossary.
- Keep `enforce_android_limit(...)` wrapping the extracted text.
- Keep the `rescue StandardError => e` / `UI.error "Anthropic provider error: #{e.message}"` / `nil` shape.

## Commands you will need

| Purpose   | Command                                              | Expected on success |
|-----------|------------------------------------------------------|---------------------|
| Install   | `bundle install`                                     | exit 0              |
| One spec  | `bundle exec rspec spec/providers/anthropic_provider_spec.rb` | all examples pass   |
| Full suite| `bundle exec rspec`                                  | 0 failures          |
| Lint      | `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb` | no offenses |

## Scope

**In scope** (the only files you should modify):
- `lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb`
- `spec/providers/anthropic_provider_spec.rb`

**Out of scope** (do NOT touch, even though they look related):
- `lib/.../helper/providers/base_provider.rb` — `build_system_instruction` / `build_prompt` are shared by all providers; do not change them.
- The `initialize` method and all class methods (`provider_name`, `optional_params`, etc.) in `anthropic_provider.rb` — only `translate` and `extract_text_from_response` change.
- `spec/spec_helper.rb` — enabling `verify_partial_doubles` is plan 005's job, not this one.
- Any other provider file or spec.

## Git workflow

- Branch: `advisor/001-fix-anthropic-provider`
- Commit style matches `git log` (plain imperative subject lines, e.g. "Fix Anthropic provider to use Messages API"). Do NOT add a `Co-Authored-By` trailer — this repo's convention is no co-author trailers.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Rewrite `translate` to use the Messages API

Replace the `translate` method body so it builds a system instruction + user message and calls `client.messages.create`. Target shape:

```ruby
def translate(text, source_locale, target_locale, glossary_terms: {})
  system_instruction = build_system_instruction(
    source_locale, target_locale,
    glossary_terms: glossary_terms,
    platform: @params[:platform]
  )

  response = @client.messages.create(
    model: @params[:model_name] || DEFAULT_MODEL,
    max_tokens: (@params[:max_tokens] || DEFAULT_MAX_TOKENS).to_i,
    temperature: (@params[:temperature] || DEFAULT_TEMPERATURE).to_f,
    system_: system_instruction,
    messages: [
      { role: "user", content: text }
    ]
  )

  enforce_android_limit(extract_text_from_response(response))
rescue StandardError => e
  UI.error "Anthropic provider error: #{e.message}"
  nil
end
```

**Verify**: `grep -n "messages.create\|max_tokens_to_sample\|\.complete(" lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb` → shows `messages.create`, and NO `max_tokens_to_sample` and NO `.complete(`.

### Step 2: Rewrite `extract_text_from_response` for typed content blocks

Replace the private method so it reads the typed `Message` object:

```ruby
def extract_text_from_response(response)
  return nil if response.nil?

  content = response.content
  return nil if content.nil? || content.empty?

  text = content
         .select { |block| block.respond_to?(:text) && block.type == :text }
         .map(&:text)
         .join
         .strip

  text.empty? ? nil : text
end
```

**Verify**: `grep -n "response\['completion'\]\|response.content" lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb` → shows `response.content`, NOT `response['completion']`.

### Step 3: Rewrite the spec to mock the real API

In `spec/providers/anthropic_provider_spec.rb`, the `#translate` describe block must mock `client.messages.create` instead of `client.complete`, and build a fake typed response. Because the executor cannot construct a real `Anthropic::Models::Message`, build a stand-in text block double and a response double whose `.content` returns `[text_block]`.

Replace the `mock_response` / `mock_client` setup and every `receive(:complete)` with this pattern. Add near the top of the `#translate` describe block:

```ruby
# A fake text content block matching Anthropic::Models::TextBlock's interface:
# responds to #type (=> :text) and #text (=> the string).
def text_block(str)
  instance_double('Anthropic::Models::TextBlock', type: :text, text: str)
end

# A fake Message: responds to #content => array of blocks.
def message_with(str)
  instance_double('Anthropic::Models::Message', content: [text_block(str)])
end

let(:messages_resource) { double('Anthropic::Resources::Messages') }

before do
  allow(mock_client).to receive(:messages).and_return(messages_resource)
end
```

Then convert each existing example:
- `allow(mock_client).to receive(:complete).and_return(mock_response)` → `allow(messages_resource).to receive(:create).and_return(message_with('Hallo Welt'))`
- `expect(mock_client).to receive(:complete) do |args| … end` → `expect(messages_resource).to receive(:create) do |args| … end`
- Assertions on `args[:prompt]` → assert on `args[:system_]` for instruction/glossary/context/Android content, and on `args[:messages]` for the source text. Example for the "builds correct prompt" case:

```ruby
expect(messages_resource).to receive(:create) do |args|
  expect(args[:system_]).to include('Translate the following release notes from en-US to de-DE')
  expect(args[:messages].first[:content]).to eq('Hello World')
  message_with('Hallo Welt')
end
```

- `hash_including(max_tokens_to_sample: 1024)` → `hash_including(max_tokens: 1024)`. Do this for all three max_tokens examples (default 1024, custom 2048, string-coerced 512).
- The whitespace-stripping example: return `message_with('  Hallo Welt  ')` and expect `'Hallo Welt'`.
- The glossary / context / Android examples currently assert on `args[:prompt]`; switch them to `args[:system_]` (these belong in the system instruction now, exactly as the OpenAI spec asserts on its system message — see `spec/providers/openai_provider_spec.rb` for the structural pattern).
- The StandardError examples: `allow(messages_resource).to receive(:create).and_raise(StandardError.new('Network timeout'))`.

Leave the `#initialize`, `.optional_params`, `.provider_name`, `#valid?`, `#params`, `#config_errors` describe blocks unchanged — they don't touch the API call.

**Verify**: `grep -n "complete\|max_tokens_to_sample\|'completion'" spec/providers/anthropic_provider_spec.rb` → no matches.

### Step 4: Run the spec and the full suite

**Verify**:
- `bundle exec rspec spec/providers/anthropic_provider_spec.rb` → all examples pass, 0 failures.
- `bundle exec rspec` → 0 failures (same example count as before minus none; you only rewrote assertions).
- `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb` → no offenses.

## Test plan

- The existing `spec/providers/anthropic_provider_spec.rb` is the test file; it is being rewritten in place (Step 3), not added to.
- Cases that must remain covered after the rewrite: successful translation returns text; whitespace stripped; system instruction contains source/target locales; source text passed as user message; custom + default model; custom + default temperature; custom + default max_tokens; type coercion of temperature/max_tokens; glossary terms appear in `system_`; no glossary section when empty; Android limit text in `system_`; context in `system_`; `nil` on StandardError; error logged.
- Structural pattern to follow for system/user message assertions: `spec/providers/openai_provider_spec.rb` (it already mocks a system+user split via `client.chat`).
- Verification: `bundle exec rspec spec/providers/anthropic_provider_spec.rb` → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -rn "\.complete(\|max_tokens_to_sample\|response\['completion'\]" lib/ spec/providers/anthropic_provider_spec.rb` returns no matches
- [ ] `grep -n "messages.create" lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb` returns exactly one match
- [ ] `bundle exec rspec spec/providers/anthropic_provider_spec.rb` exits 0, all examples pass
- [ ] `bundle exec rspec` exits 0, 0 failures
- [ ] `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/anthropic_provider.rb` reports no offenses
- [ ] `git status` shows only the two in-scope files modified
- [ ] `plans/README.md` status row for 001 updated

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows `anthropic_provider.rb` already calls `messages.create` (someone fixed it) — the finding is gone; mark and report.
- `Anthropic::Resources::Messages#create` is not present in the installed gem (run `ruby -e "require 'anthropic'; puts Anthropic::Client.instance_method(:messages) ? 'ok' : 'no'"` — if it errors, the gem version differs from what this plan assumes).
- The full suite has failures in files **other than** `anthropic_provider_spec.rb` after your change — that means you touched something out of scope; revert and report.
- You find you must edit `base_provider.rb` to make this work — that's a sign the approach is wrong for this plan; stop and report.

## Maintenance notes

- The default model `claude-sonnet-4.5` (in `DEFAULT_MODEL`) is a Messages-API model and only works via `messages.create` — which is exactly why the legacy `complete` path was broken. Any future model default must remain a Messages-API model.
- Reviewer should scrutinize: that the spec mocks `messages.create` (not `complete`), and that the new response double exposes `.content` returning typed blocks — not a hash. A spec that mocks a hash response would re-introduce the fictional-API problem.
- Follow-up deferred to **plan 005**: enabling RSpec `verify_partial_doubles` so this class of "mock a method that doesn't exist" bug is caught automatically, plus a contract test that the provider's calls resolve against the real client.
