# Plan 003: A failed translation never destroys existing localized files

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 0ce8cd9..HEAD -- lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb spec/translate_gpt_release_notes_action_spec.rb`
> If either in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S–M
- **Risk**: MED
- **Depends on**: plans/002-action-orchestration-tests.md (the characterization tests must exist so this fix is verifiable)
- **Category**: bug
- **Planned at**: commit `0ce8cd9`, 2026-06-15

## Why this matters

When a provider returns `nil` for a translation — which happens on any API error, a timeout, or (until plan 001 lands) every single Anthropic call — the action writes that `nil` straight to disk. `File.write(path, nil)` produces an **empty file**, silently destroying whatever good translation was there before. Then `File.write(last_run_file, Time.now.to_i)` runs **unconditionally**, so the next invocation sees the unchanged source, decides "no changes," and skips — meaning the wiped translations are never regenerated. A single transient API hiccup can therefore permanently blank out a user's localized release notes across every locale. This plan makes a `nil`/empty translation a no-op for that locale (existing file untouched) and only records a successful run when at least one translation actually succeeded.

## Current state

- `lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb`.

The loop and timestamp write (lines 54–63):

```ruby
helper = Helper::TranslateGptReleaseNotesHelper.new(params)
translated_texts = locales.each_with_object({}) do |locale, translations|
  next if locale == params[:master_locale]  # Skip master locale
  translations[locale] = helper.translate_text(master_texts, locale, params[:platform])
end

update_translated_texts(base_directory, translated_texts, is_ios, params)

# Store the current time as the last run time
File.write(last_run_file, Time.now.to_i)
```

The writer (lines 96–110):

```ruby
def self.update_translated_texts(base_directory, translated_texts, is_ios, params)
  translated_texts.each do |locale, text|
    next if locale == params[:master_locale]  # Skip master locale

    target_path = is_ios ? File.join(base_directory, locale) : File.join(base_directory, locale, 'changelogs')

    # Ensure target path exists or create it
    FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)

    filename = is_ios ? 'release_notes.txt' : highest_numbered_file(File.join(base_directory, params[:master_locale], 'changelogs'))

    # Write the translated text to the file
    File.write(File.join(target_path, filename), text)
  end
end
```

- `spec/translate_gpt_release_notes_action_spec.rb` — after plan 002, contains a characterization example labeled `CHARACTERIZATION OF CURRENT BEHAVIOR` asserting the current empty-file overwrite. This example must be flipped by this plan.

### Conventions to match

- The codebase uses `UI.message` / `UI.warning` / `UI.error` for user-facing logs (see `helper/providers/base_provider.rb` and the action). Use `UI.warning` for a skipped locale.
- Keep the existing method signatures; this is a behavior fix, not a refactor.

## Commands you will need

| Purpose    | Command                                                        | Expected on success |
|------------|---------------------------------------------------------------|---------------------|
| Install    | `bundle install`                                              | exit 0              |
| This spec  | `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` | all pass |
| Full suite | `bundle exec rspec`                                           | 0 failures          |
| Lint       | `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` | no offenses |

## Scope

**In scope** (the only files you should modify):
- `lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb`
- `spec/translate_gpt_release_notes_action_spec.rb` (flip the characterization example + add success-tracking examples)

**Out of scope** (do NOT touch):
- Any provider file — providers already return `nil` on error; that contract is fine. This fix is purely in the action layer.
- `helper/translate_gpt_release_notes_helper.rb` — `translate_text` returning `nil` is the expected signal; don't change it.

## Git workflow

- Branch: `advisor/003-prevent-nil-data-loss`
- Commit style: plain imperative subject (e.g. "Skip writing on failed translation and only record successful runs"). No `Co-Authored-By` trailer.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Skip nil/empty translations in `update_translated_texts`

Guard the write so a `nil` or blank translation never touches disk:

```ruby
def self.update_translated_texts(base_directory, translated_texts, is_ios, params)
  translated_texts.each do |locale, text|
    next if locale == params[:master_locale]  # Skip master locale

    if text.nil? || text.to_s.strip.empty?
      UI.warning("Skipping #{locale}: translation failed or returned empty; existing file left unchanged.")
      next
    end

    target_path = is_ios ? File.join(base_directory, locale) : File.join(base_directory, locale, 'changelogs')

    # Ensure target path exists or create it
    FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)

    filename = is_ios ? 'release_notes.txt' : highest_numbered_file(File.join(base_directory, params[:master_locale], 'changelogs'))

    # Write the translated text to the file
    File.write(File.join(target_path, filename), text)
  end
end
```

**Verify**: `grep -n "translation failed or returned empty" lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` → one match.

### Step 2: Only record a successful run when at least one translation succeeded

In `run`, replace the unconditional `File.write(last_run_file, Time.now.to_i)` so it only fires when at least one locale produced a non-empty translation. Change the tail of `run` to:

```ruby
update_translated_texts(base_directory, translated_texts, is_ios, params)

# Only mark the run successful if at least one translation actually succeeded —
# otherwise a transient failure would suppress the next run's retry.
any_success = translated_texts.any? { |locale, text| locale != params[:master_locale] && !text.nil? && !text.to_s.strip.empty? }
if any_success
  File.write(last_run_file, Time.now.to_i)
else
  UI.error("No translations succeeded; not updating #{last_run_file} so the next run will retry.")
end
```

**Verify**: `grep -n "any_success\|not updating" lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` → matches present.

### Step 3: Flip the plan-002 characterization example

In `spec/translate_gpt_release_notes_action_spec.rb`, find the example commented `CHARACTERIZATION OF CURRENT BEHAVIOR`. Replace it so it asserts the **fixed** behavior: the pre-seeded file is preserved and `last_successful_run.txt` is NOT created when all translations fail. Remove the `CHARACTERIZATION OF CURRENT BEHAVIOR` comment. Target:

```ruby
context 'when all translations fail (provider returns nil)' do
  it 'leaves existing target files untouched and does not record a successful run' do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:warning)
    allow(Fastlane::UI).to receive(:error)
    allow_any_instance_of(Fastlane::Helper::TranslateGptReleaseNotesHelper)
      .to receive(:translate_text).and_return(nil)

    with_ios_metadata do
      File.write('fastlane/metadata/fr-FR/release_notes.txt', 'bonnes notes existantes')

      Fastlane::Actions::TranslateGptReleaseNotesAction.run(
        provider: 'openai', platform: 'ios', master_locale: 'en-US', api_token: 'x'
      )

      expect(File.read('fastlane/metadata/fr-FR/release_notes.txt')).to eq('bonnes notes existantes')
      expect(File.exist?('last_successful_run.txt')).to be false
    end
  end
end
```

### Step 4: Add a partial-success example

Add an example where one locale succeeds and another fails — the good one is written, the failed one is preserved, and the run IS recorded (because at least one succeeded):

```ruby
context 'when some translations fail' do
  it 'writes the successful locale, preserves the failed locale, and records the run' do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:warning)
    allow(Fastlane::UI).to receive(:error)
    allow_any_instance_of(Fastlane::Helper::TranslateGptReleaseNotesHelper)
      .to receive(:translate_text) do |_inst, _text, locale, _platform|
        locale == 'fr-FR' ? 'notes traduites' : nil
      end

    with_ios_metadata do
      File.write('fastlane/metadata/de-DE/release_notes.txt', 'alte notizen')

      Fastlane::Actions::TranslateGptReleaseNotesAction.run(
        provider: 'openai', platform: 'ios', master_locale: 'en-US', api_token: 'x'
      )

      expect(File.read('fastlane/metadata/fr-FR/release_notes.txt')).to eq('notes traduites')
      expect(File.read('fastlane/metadata/de-DE/release_notes.txt')).to eq('alte notizen')
      expect(File.exist?('last_successful_run.txt')).to be true
    end
  end
end
```

**Verify**: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → all pass, including the flipped and new examples.

### Step 5: Run the full suite and lint

**Verify**:
- `bundle exec rspec` → 0 failures.
- `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb spec/translate_gpt_release_notes_action_spec.rb` → no offenses.

## Test plan

- Tests live in `spec/translate_gpt_release_notes_action_spec.rb`, building on the plan-002 `with_ios_metadata` harness.
- Cases: all-fail leaves files intact + no run recorded; partial success writes good locale, preserves failed locale, records run; (existing happy-path example from plan 002 still passes).
- Verification: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "translation failed or returned empty" lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` → one match
- [ ] `grep -n "any_success" lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` → at least one match
- [ ] `grep -n "CHARACTERIZATION OF CURRENT BEHAVIOR" spec/translate_gpt_release_notes_action_spec.rb` → no matches (the marker is gone, the example is flipped)
- [ ] `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` exits 0, all pass
- [ ] `bundle exec rspec` exits 0, 0 failures
- [ ] `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb spec/translate_gpt_release_notes_action_spec.rb` → no offenses
- [ ] `git status` shows only the two in-scope files modified
- [ ] `plans/README.md` status row for 003 updated

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 002 has not landed (the `with_ios_metadata` harness and the `CHARACTERIZATION OF CURRENT BEHAVIOR` example don't exist in the spec). This plan depends on 002; do not recreate that scaffolding here — report the missing dependency.
- The drift check shows `update_translated_texts` already guards against `nil` — the finding may be fixed; report.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The "record run only on success" logic uses `translated_texts`. If a future change makes the loop write incrementally (per-locale, streaming) instead of collecting a hash, the success-tracking must move accordingly.
- Reviewer should confirm: empty-string translations are treated the same as `nil` (both skipped) — a provider that returns `""` is also a failure, not a valid "blank release notes" result.
- Consider (deferred): a future enhancement could write a per-locale success record rather than a single global `last_successful_run.txt`, so a locale that failed retries next run even if others succeeded. Out of scope here.
