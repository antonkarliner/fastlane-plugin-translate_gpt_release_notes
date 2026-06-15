# Plan 005: Tests catch provider/SDK contract drift automatically

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 0ce8cd9..HEAD -- spec/spec_helper.rb spec/providers/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S–M
- **Risk**: MED
- **Depends on**: plans/001-fix-anthropic-provider-messages-api.md (the Anthropic spec must already mock the real `messages.create` API, or enabling strict doubles will fail it)
- **Category**: tests / dx (direction)
- **Planned at**: commit `0ce8cd9`, 2026-06-15

## Why this matters

The root cause behind plan 001 wasn't one wrong method name — it was that **nothing checks provider code against the real SDK**. The Anthropic spec mocked a `complete` method that doesn't exist on the gem, so the suite was green while the feature was 100% broken. Two cheap, durable guards close this gap for good: (1) enable RSpec's `verify_partial_doubles`, which makes mocking a nonexistent method on a real class an immediate test failure; and (2) add a small "contract" test per provider asserting the methods/objects the provider actually calls exist on the real client class. Together they would have caught plan 001 on the first run and will catch the next SDK bump. This is the systemic fix the four bug plans only address case-by-case.

## Current state

- `spec/spec_helper.rb` (full file):

```ruby
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'

# SimpleCov.minimum_coverage 95
SimpleCov.start

# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require 'fastlane' # to import the Action super class
require 'fastlane/plugin/translate_gpt_release_notes' # import the actual plugin

Fastlane.load_actions # load other actions (in case your plugin calls other actions or shared values)
```

There is **no `RSpec.configure` block** and `verify_partial_doubles` is off (RSpec default is off for backward compatibility).

- The provider specs mock real client classes:
  - `spec/providers/openai_provider_spec.rb` — mocks `OpenAI::Client#chat` (exists ✓).
  - `spec/providers/anthropic_provider_spec.rb` — after plan 001, mocks `client.messages.create` (exists ✓). **Before plan 001 it mocks `complete` (does NOT exist) — that is exactly why this plan depends on 001.**
  - `spec/providers/deepl_provider_spec.rb` — mocks the `DeepL` module's `.translate` (exists ✓).
  - `spec/providers/gemini_provider_spec.rb` — mocks HTTP (`Net::HTTP`), not an SDK client.

### How `verify_partial_doubles` behaves

With it enabled, `allow(real_object).to receive(:method)` raises if `real_object` does not respond to `:method`. `instance_double('SomeClass', …)` already verifies method existence against `SomeClass`. Plain `double('label')` is unaffected (it's not a partial double of a real object). So the risk is limited to `allow(<real instance/class>).to receive(<missing method>)`.

### Conventions to match

- RSpec specs, loaded via `.rspec` → `spec_helper`. No `.rspec` change needed.
- Provider class methods to reference in contract tests: each provider calls a specific client method (see each provider's `translate`).

## Commands you will need

| Purpose    | Command                                       | Expected on success |
|------------|-----------------------------------------------|---------------------|
| Install    | `bundle install`                              | exit 0              |
| Full suite | `bundle exec rspec`                           | 0 failures          |
| Providers  | `bundle exec rspec spec/providers/`           | all pass            |
| Lint       | `bundle exec rubocop spec/`                   | no offenses         |

## Scope

**In scope** (the only files you should modify):
- `spec/spec_helper.rb`
- `spec/providers/provider_contract_spec.rb` (create)
- Any provider spec that fails ONLY because it mocks a method missing on a real client — and only to correct the mock to the real method (see STOP conditions for the boundary).

**Out of scope** (do NOT touch):
- Any `lib/` production code — if a contract test reveals a real bug, that's a finding to report, not to fix here (plan 001 already covers the known one).
- Rewriting passing specs for style.

## Git workflow

- Branch: `advisor/005-verify-doubles-contract-tests`
- Commit style: plain imperative subject (e.g. "Enable verify_partial_doubles and add provider contract tests"). No `Co-Authored-By` trailer.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Enable strict partial doubles

Append an `RSpec.configure` block to `spec/spec_helper.rb`:

```ruby
RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # Fail fast if a spec mocks a method that doesn't exist on the real object.
    # This catches provider code drifting from the actual SDK API.
    mocks.verify_partial_doubles = true
  end
end
```

**Verify**: `bundle exec rspec 2>&1 | tail -5` — note the result. If 0 failures, proceed to Step 2. If there are failures, they are exactly the fictional-API mocks this guard is meant to catch — go to Step 1a.

### Step 1a: Triage any new failures (only if Step 1 produced failures)

For each failing example, read the error. It will say something like `the X class does not implement the instance method: Y`.

- If the failing spec is `anthropic_provider_spec.rb` and the missing method is `complete`: **plan 001 has not landed.** STOP — this plan depends on 001.
- If the failure is a real-but-renamed mock on a method that genuinely exists under a different name on the real client (verify by inspecting the gem), correct the mock to the real method name. Document each such change in your report.
- If the failure indicates the **production code** calls a method that doesn't exist on the real client (a genuine bug like plan 001's), **STOP and report it** — do not fix production code in this plan.

**Verify**: after triage, `bundle exec rspec` → 0 failures, and you can name every change you made.

### Step 2: Add a provider contract spec

Create `spec/providers/provider_contract_spec.rb`. These tests assert the real SDK exposes what each provider relies on — they do not hit the network. Use the real gem classes:

```ruby
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
```

**Verify**: `bundle exec rspec spec/providers/provider_contract_spec.rb` → all pass.

### Step 3: Run the full suite and lint

**Verify**:
- `bundle exec rspec` → 0 failures.
- `bundle exec rubocop spec/` → no offenses (if RuboCop objects to the contract spec style, match the conventions used in the existing provider specs; do not add inline disables unless already used elsewhere).

## Test plan

- New file: `spec/providers/provider_contract_spec.rb` with the contract assertions above.
- `spec/spec_helper.rb`: `verify_partial_doubles = true`.
- Verification: `bundle exec rspec` → 0 failures, contract spec present and passing.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "verify_partial_doubles = true" spec/spec_helper.rb` → one match
- [ ] `test -f spec/providers/provider_contract_spec.rb` → exists
- [ ] `bundle exec rspec spec/providers/provider_contract_spec.rb` exits 0, all pass
- [ ] `bundle exec rspec` exits 0, 0 failures
- [ ] `bundle exec rubocop spec/` → no offenses
- [ ] `git status` shows only in-scope files modified (no `lib/` changes)
- [ ] `plans/README.md` status row for 005 updated

## STOP conditions

Stop and report back (do not improvise) if:

- Enabling `verify_partial_doubles` makes `anthropic_provider_spec.rb` fail on `complete` — plan 001 hasn't landed; this plan depends on it.
- A contract test (or a newly strict partial double) reveals a provider calling a method that doesn't exist on its real SDK client — report it as a new bug; do NOT modify `lib/` to fix it here.
- More than the provider specs fail after Step 1, in ways unrelated to SDK method existence (e.g. fastlane internals) — report the output; the strict-doubles change may interact with `Fastlane::UI` stubs in a way that needs a scoped decision.

## Maintenance notes

- The contract spec is the early-warning system for gem upgrades. When bumping `anthropic`, `ruby-openai`, or `deepl-rb` (see plan 007 for the ruby-openai upgrade), run `bundle exec rspec spec/providers/provider_contract_spec.rb` first — a failure there means the provider code needs updating for the new SDK.
- Reviewer should confirm the contract tests assert against the **real** gem classes (`OpenAI::Client`, `Anthropic::Resources::Messages`, `DeepL`), not doubles — a contract test that mocks the thing it's verifying proves nothing.
- `verify_partial_doubles` is now a standing guard; any future spec that mocks a nonexistent method will fail immediately, which is the intended behavior.
