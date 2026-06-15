# Plan 004: DeepL produces region-qualified targets for English & Portuguese

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 0ce8cd9..HEAD -- lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb spec/providers/deepl_provider_spec.rb`
> If either in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `0ce8cd9`, 2026-06-15

## Why this matters

The DeepL provider normalizes every locale by stripping the region: `normalize_locale('en-US') => 'EN'`. The 2-letter result is passed straight to `DeepL.translate(text, source_lang, target_lang, options)` as the **target** language. But DeepL's API requires a region-qualified target for English (`EN-US` or `EN-GB`) and Portuguese (`PT-PT` or `PT-BR`); the bare `EN` and `PT` codes are deprecated as targets and the API rejects or warns on them. So translating *into* English or Portuguese — both common app locales — fails or returns a deprecation, while the DeepL provider silently returns `nil` (and, until plan 003 lands, blanks the file). The source language is unaffected: DeepL's source accepts only the bare 2-letter code, so `en-US -> EN` is correct for source. This plan splits normalization into source vs. target, keeping source 2-letter and giving target a valid region for English/Portuguese.

## Current state

- `lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb`.

The `translate` method (lines 94–99) normalizes both source and target with the same method:

```ruby
def translate(text, source_locale, target_locale, glossary_terms: {})
  # DeepL uses ISO 639-1 language codes (2-letter codes)
  # Convert locales like 'en-US' to 'EN'
  source_lang = normalize_locale(source_locale)
  target_lang = normalize_locale(target_locale)
```

The shared normalizer (lines 138–140):

```ruby
def normalize_locale(locale)
  locale.to_s.split('-').first.upcase
end
```

- `spec/providers/deepl_provider_spec.rb` — existing examples translate to `de-DE`/`fr` (→ `DE`/`FR`, region-less, which is correct and unaffected) and assert `with('Hello World', 'EN', 'DE', …)`. None of them target English or Portuguese, so they will keep passing unchanged.

### DeepL target-language rules (the facts this fix encodes)

- English target: must be `EN-US` or `EN-GB` (never bare `EN`).
- Portuguese target: must be `PT-PT` or `PT-BR` (never bare `PT`).
- All other targets: bare 2-letter uppercase (e.g. `DE`, `FR`, `JA`, `RU`).
- Source language (all languages): bare 2-letter uppercase.

### Conventions to match

- Private helper methods, documented with a short comment block as the existing `normalize_locale` is.
- `DeepL.translate(text, source_lang, target_lang, options)` is the call site (verified against `deepl-rb 3.6.1`, `DeepL.translate(text, source_lang, target_lang, options = {})`). `target_lang` is passed through verbatim to the API, so the string this code produces is exactly what DeepL receives.

## Commands you will need

| Purpose    | Command                                                  | Expected on success |
|------------|---------------------------------------------------------|---------------------|
| Install    | `bundle install`                                        | exit 0              |
| This spec  | `bundle exec rspec spec/providers/deepl_provider_spec.rb` | all pass |
| Full suite | `bundle exec rspec`                                     | 0 failures          |
| Lint       | `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb` | no offenses |

## Scope

**In scope** (the only files you should modify):
- `lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb`
- `spec/providers/deepl_provider_spec.rb` (add cases)

**Out of scope** (do NOT touch):
- The `initialize` free/paid host detection — that logic is correct.
- Any other provider; the locale issue is DeepL-specific (other providers receive full locale codes and pass them to LLM prompts).

## Git workflow

- Branch: `advisor/004-deepl-target-locale`
- Commit style: plain imperative subject (e.g. "Use region-qualified DeepL targets for English and Portuguese"). No `Co-Authored-By` trailer.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Split normalization into source and target

In `deepl_provider.rb`, change the two call sites in `translate`:

```ruby
source_lang = normalize_source_locale(source_locale)
target_lang = normalize_target_locale(target_locale)
```

Then replace the single private `normalize_locale` with two methods. Keep a clear comment on each:

```ruby
# Normalizes a locale for use as the DeepL SOURCE language.
# DeepL source accepts only the bare 2-letter ISO 639-1 code.
# 'en-US' -> 'EN', 'de-DE' -> 'DE'.
def normalize_source_locale(locale)
  locale.to_s.split(/[-_]/).first.to_s.upcase
end

# Normalizes a locale for use as the DeepL TARGET language.
# DeepL requires a region for English ('EN-US'/'EN-GB') and Portuguese
# ('PT-PT'/'PT-BR'); bare 'EN'/'PT' are deprecated targets and rejected.
# All other targets use the bare 2-letter code.
def normalize_target_locale(locale)
  parts = locale.to_s.split(/[-_]/)
  lang = parts[0].to_s.downcase
  region = parts[1].to_s.upcase

  case lang
  when 'en'
    region == 'GB' ? 'EN-GB' : 'EN-US'
  when 'pt'
    region == 'BR' ? 'PT-BR' : 'PT-PT'
  else
    lang.upcase
  end
end
```

(Defaulting unknown English regions to `EN-US` and unknown Portuguese regions to `PT-PT` guarantees a valid DeepL target rather than passing through an unsupported `EN-CA`-style code.)

**Verify**: `grep -n "normalize_locale\|normalize_source_locale\|normalize_target_locale" lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb` → shows the two new methods and NO remaining `normalize_locale` definition or call.

### Step 2: Add spec cases for English and Portuguese targets

In `spec/providers/deepl_provider_spec.rb`, add a context covering the region-qualified targets. Match the existing `expect(DeepL).to receive(:translate).with(...)` pattern (see the existing examples around the `mock_result` setup):

```ruby
context 'target language normalization' do
  let(:mock_result) { double('DeepL result', text: 'translated') }

  before { allow(Fastlane::UI).to receive(:message) }

  it 'uses EN-US for a bare en target' do
    expect(DeepL).to receive(:translate).with('Hello', 'EN', 'EN-US', anything).and_return(mock_result)
    provider.translate('Hello', 'de-DE', 'en')
  end

  it 'uses EN-GB for an en-GB target' do
    expect(DeepL).to receive(:translate).with('Hello', 'EN', 'EN-GB', anything).and_return(mock_result)
    provider.translate('Hello', 'de-DE', 'en-GB')
  end

  it 'uses EN-US for an en-US target' do
    expect(DeepL).to receive(:translate).with('Hello', 'EN', 'EN-US', anything).and_return(mock_result)
    provider.translate('Hello', 'de-DE', 'en-US')
  end

  it 'uses PT-PT for a bare pt target' do
    expect(DeepL).to receive(:translate).with('Hello', 'EN', 'PT-PT', anything).and_return(mock_result)
    provider.translate('Hello', 'en-US', 'pt')
  end

  it 'uses PT-BR for a pt-BR target' do
    expect(DeepL).to receive(:translate).with('Hello', 'EN', 'PT-BR', anything).and_return(mock_result)
    provider.translate('Hello', 'en-US', 'pt-BR')
  end

  it 'uses a bare code for non-region languages' do
    expect(DeepL).to receive(:translate).with('Hello', 'EN', 'JA', anything).and_return(mock_result)
    provider.translate('Hello', 'en-US', 'ja-JP')
  end
end
```

Use whatever `let(:provider)` / valid-params setup the existing spec already defines (do not redefine it if it's in a shared `before`/`let` — reuse it; check the top of the file).

**Verify**: `bundle exec rspec spec/providers/deepl_provider_spec.rb` → all pass, including the 6 new examples and the unchanged existing ones.

### Step 3: Run the full suite and lint

**Verify**:
- `bundle exec rspec` → 0 failures.
- `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb spec/providers/deepl_provider_spec.rb` → no offenses.

## Test plan

- Tests live in `spec/providers/deepl_provider_spec.rb`.
- Cases: `en`→`EN-US`, `en-GB`→`EN-GB`, `en-US`→`EN-US`, `pt`→`PT-PT`, `pt-BR`→`PT-BR`, non-region (`ja-JP`→`JA`); existing `de-DE`/`fr` examples remain green proving no regression.
- Structural pattern: existing `expect(DeepL).to receive(:translate).with(...)` examples in the same file.
- Verification: `bundle exec rspec spec/providers/deepl_provider_spec.rb` → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "def normalize_locale" lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb` → no matches (old method removed)
- [ ] `grep -n "normalize_target_locale\|normalize_source_locale" lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb` → at least 4 matches (2 defs + 2 call sites)
- [ ] `bundle exec rspec spec/providers/deepl_provider_spec.rb` exits 0, all pass
- [ ] `bundle exec rspec` exits 0, 0 failures
- [ ] `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/helper/providers/deepl_provider.rb spec/providers/deepl_provider_spec.rb` → no offenses
- [ ] `git status` shows only the two in-scope files modified
- [ ] `plans/README.md` status row for 004 updated

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows the normalization already distinguishes source/target — the finding may be fixed; report.
- An existing DeepL spec example fails after your change (it shouldn't — none target EN/PT). If one does, you changed source normalization incorrectly; revert and report.

## Maintenance notes

- DeepL periodically expands supported target variants (e.g. additional Chinese scripts `ZH-HANS`/`ZH-HANT`). If users request those, extend `normalize_target_locale` with the same case pattern. Document any new mapping in the README's DeepL section.
- Reviewer should confirm source stays bare 2-letter (`EN`, not `EN-US`) — DeepL's source endpoint rejects region-qualified source codes.
- The README's DeepL section doesn't currently mention locale normalization; a docs note is a reasonable (deferred) follow-up.
