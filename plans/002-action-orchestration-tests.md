# Plan 002: Characterization tests for the action's orchestration logic

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
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `0ce8cd9`, 2026-06-15

## Why this matters

The action's `run` method is the heart of the plugin — it lists locales, reads the master file, loops over targets calling the provider, writes results to disk, and manages the incremental-skip timestamp. **None of that is tested.** The existing `spec/translate_gpt_release_notes_action_spec.rb` only exercises early-return paths (missing directory, bad provider, credential checks) — it never lets `run` reach the translation loop or file writing. The suite reports 95% line coverage and 0 failures, yet a completely broken provider (plan 001) and a data-loss bug (plan 003) both ship undetected. This plan adds **characterization tests** that pin down the current real behavior of the loop and file I/O, so the plan 003 fix can be made safely and future regressions are caught. It deliberately documents the **current buggy behavior** (nil overwrites files) as a test marked for change in plan 003 — characterization first, fix second.

## Current state

- `lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` — the action. Key orchestration excerpt (lines 35–63):

```ruby
locales = list_locales(base_directory)
master_texts, master_file_path = fetch_master_texts(base_directory, params[:master_locale], is_ios)

unless master_texts && master_file_path
  UI.message("Master file not found, skipping translation.")
  return
end

if File.exist?(last_run_file) && File.exist?(master_file_path)
  last_run_time = File.read(last_run_file).to_i
  file_mod_time = File.mtime(master_file_path).to_i
  if file_mod_time <= last_run_time
    UI.message("No changes in source file detected, translation skipped.")
    return
  end
end

helper = Helper::TranslateGptReleaseNotesHelper.new(params)
translated_texts = locales.each_with_object({}) do |locale, translations|
  next if locale == params[:master_locale]  # Skip master locale
  translations[locale] = helper.translate_text(master_texts, locale, params[:platform])
end

update_translated_texts(base_directory, translated_texts, is_ios, params)

File.write(last_run_file, Time.now.to_i)
```

- `update_translated_texts` (lines 96–110) writes each locale's text to disk; `File.write(path, nil)` produces an empty file (this is the bug plan 003 fixes — characterize it here, don't fix it):

```ruby
def self.update_translated_texts(base_directory, translated_texts, is_ios, params)
  translated_texts.each do |locale, text|
    next if locale == params[:master_locale]
    target_path = is_ios ? File.join(base_directory, locale) : File.join(base_directory, locale, 'changelogs')
    FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)
    filename = is_ios ? 'release_notes.txt' : highest_numbered_file(File.join(base_directory, params[:master_locale], 'changelogs'))
    File.write(File.join(target_path, filename), text)
  end
end
```

- iOS layout: `fastlane/metadata/<locale>/release_notes.txt`. Android layout: `fastlane/metadata/android/<locale>/changelogs/<version>.txt`.
- `spec/translate_gpt_release_notes_action_spec.rb` — existing spec, 127 lines, only early-return cases.

### Test fixtures already in the repo (use these as layout references; do NOT translate against them)

- `test_fixtures/ios/metadata/en-US/release_notes.txt`, plus `fr-FR/`, `de-DE/`, `ja-JP/`.
- `test_fixtures/android/metadata/android/en-US/changelogs/100.txt`, plus other locales.

These show the directory shape. Your tests should build their **own** temp directories (see conventions) rather than mutating these tracked fixtures.

### Conventions to match

- RSpec, no `rails_helper`; `spec/spec_helper.rb` is loaded via `.rspec`. Tests `describe` the class and use `allow`/`expect` doubles.
- The existing action spec mocks `Fastlane::Helper::CredentialResolver` class methods and `Fastlane::UI`. Follow that.
- For filesystem tests, use Ruby's `Dir.mktmpdir` (require `tmpdir`) and `Dir.chdir` into it so the action's relative paths (`fastlane/metadata`, `last_successful_run.txt`) resolve inside the temp dir. Always wrap in an `around` or `before/after` that cleans up.

## Commands you will need

| Purpose    | Command                                                        | Expected on success |
|------------|---------------------------------------------------------------|---------------------|
| Install    | `bundle install`                                              | exit 0              |
| This spec  | `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` | all pass |
| Full suite | `bundle exec rspec`                                           | 0 failures          |
| Lint       | `bundle exec rubocop spec/translate_gpt_release_notes_action_spec.rb` | no offenses |

## Scope

**In scope** (the only files you should modify):
- `spec/translate_gpt_release_notes_action_spec.rb` (add to it)

**Out of scope** (do NOT touch):
- `lib/.../actions/translate_gpt_release_notes_action.rb` — this plan adds tests for current behavior only. The fix is plan 003. Do not change production code here.
- The `test_fixtures/` directory — read its layout, but tests must use their own temp dirs.
- Any provider spec or helper spec.

## Git workflow

- Branch: `advisor/002-action-orchestration-tests`
- Commit style: plain imperative subject (e.g. "Add characterization tests for action orchestration"). No `Co-Authored-By` trailer.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add a filesystem harness to the spec

At the top of `spec/translate_gpt_release_notes_action_spec.rb`, add `require 'tmpdir'` and `require 'fileutils'` if not present. Introduce a helper that builds an iOS metadata tree inside a temp dir and runs the block with the cwd set there. Pattern:

```ruby
def with_ios_metadata(locales: %w[en-US fr-FR de-DE], master_text: "New features and bug fixes")
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      locales.each do |loc|
        FileUtils.mkdir_p(File.join('fastlane', 'metadata', loc))
      end
      File.write(File.join('fastlane', 'metadata', 'en-US', 'release_notes.txt'), master_text)
      yield dir
    end
  end
end
```

(Only `en-US` gets a source file; target dirs exist but are empty, matching real usage.)

**Verify**: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → still passes (no new failing examples yet; you only added a helper method).

### Step 2: Test the happy-path translation loop writes target files

Stub the provider so no network happens. The cleanest seam is `Fastlane::Helper::TranslateGptReleaseNotesHelper#translate_text` — stub it to return a deterministic string per locale. Add a `context 'translation loop'`:

```ruby
context 'when the master file exists and providers succeed' do
  it 'writes a translated file for each non-master locale' do
    allow(Fastlane::UI).to receive(:message)
    allow_any_instance_of(Fastlane::Helper::TranslateGptReleaseNotesHelper)
      .to receive(:translate_text) { |_inst, _text, locale, _platform| "translated-#{locale}" }

    with_ios_metadata do
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(
        provider: 'openai', platform: 'ios', master_locale: 'en-US', api_token: 'x'
      )

      expect(File.read('fastlane/metadata/fr-FR/release_notes.txt')).to eq('translated-fr-FR')
      expect(File.read('fastlane/metadata/de-DE/release_notes.txt')).to eq('translated-de-DE')
      expect(File.exist?('last_successful_run.txt')).to be true
    end
  end

  it 'does not write a file for the master locale' do
    allow(Fastlane::UI).to receive(:message)
    allow_any_instance_of(Fastlane::Helper::TranslateGptReleaseNotesHelper)
      .to receive(:translate_text) { |_inst, _text, locale, _platform| "translated-#{locale}" }

    with_ios_metadata do
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(
        provider: 'openai', platform: 'ios', master_locale: 'en-US', api_token: 'x'
      )
      expect(File.read('fastlane/metadata/en-US/release_notes.txt')).to eq('New features and bug fixes')
    end
  end
end
```

Note: the `before(:each)` block at the top already stubs `CredentialResolver` to report credentials exist — keep relying on it. The provider construction inside `TranslateGptReleaseNotesHelper#initialize` still runs, but since `translate_text` is stubbed on the instance, the real `@provider.translate` is never called. If provider construction itself fails for the fake `api_token`, see the STOP conditions.

**Verify**: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → the two new examples pass.

### Step 3: Characterize the incremental-skip behavior

```ruby
context 'incremental skip' do
  it 'skips translation when the source file is older than the last run' do
    allow(Fastlane::UI).to receive(:message)
    translated = false
    allow_any_instance_of(Fastlane::Helper::TranslateGptReleaseNotesHelper)
      .to receive(:translate_text) { translated = true; 'x' }

    with_ios_metadata do
      # last run is in the future relative to the file mtime
      File.write('last_successful_run.txt', (Time.now.to_i + 3600).to_s)
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(
        provider: 'openai', platform: 'ios', master_locale: 'en-US', api_token: 'x'
      )
      expect(translated).to be false
    end
  end
end
```

**Verify**: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → passes.

### Step 4: Characterize the CURRENT (buggy) nil-handling — mark it for plan 003

This documents today's behavior so plan 003 can flip it. Add a clearly labeled example:

```ruby
context 'when a translation fails (provider returns nil)' do
  # CHARACTERIZATION OF CURRENT BEHAVIOR — this is the data-loss bug that
  # plan 003 fixes. When 003 lands, this example must be updated to assert the
  # file is left untouched and the run is NOT marked successful.
  it 'currently overwrites the target file with an empty string' do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:warning)
    allow(Fastlane::UI).to receive(:error)
    allow_any_instance_of(Fastlane::Helper::TranslateGptReleaseNotesHelper)
      .to receive(:translate_text).and_return(nil)

    with_ios_metadata do
      # Pre-seed an existing good translation that the bug will clobber
      File.write('fastlane/metadata/fr-FR/release_notes.txt', 'bonnes notes existantes')

      Fastlane::Actions::TranslateGptReleaseNotesAction.run(
        provider: 'openai', platform: 'ios', master_locale: 'en-US', api_token: 'x'
      )

      expect(File.read('fastlane/metadata/fr-FR/release_notes.txt')).to eq('')
      expect(File.exist?('last_successful_run.txt')).to be true
    end
  end
end
```

**Verify**: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → this example passes (confirming the bug exists as described).

### Step 5: Run the full suite and lint

**Verify**:
- `bundle exec rspec` → 0 failures.
- `bundle exec rubocop spec/translate_gpt_release_notes_action_spec.rb` → no offenses (if RuboCop flags `allow_any_instance_of` or block style, adjust to satisfy the repo's `.rubocop.yml`; do not add inline disables unless an existing spec already uses that pattern).

## Test plan

- All new examples live in `spec/translate_gpt_release_notes_action_spec.rb`.
- Cases: per-locale target file written (happy path); master locale not overwritten; `last_successful_run.txt` created; incremental skip when source older than last run; **current** nil-overwrite behavior (characterization, labeled for plan 003).
- Structural pattern: the existing examples in this same file (credential stubbing, `Dir.exist?` stubbing) plus `Dir.mktmpdir`/`Dir.chdir` for real filesystem assertions.
- Verification: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → all pass, ≥5 new examples.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` exits 0 with at least 5 more examples than before (was a small file of early-return cases)
- [ ] `bundle exec rspec` exits 0, 0 failures
- [ ] `grep -n "Dir.mktmpdir" spec/translate_gpt_release_notes_action_spec.rb` returns at least one match
- [ ] `grep -n "CHARACTERIZATION OF CURRENT BEHAVIOR" spec/translate_gpt_release_notes_action_spec.rb` returns one match (the plan-003 marker)
- [ ] `git status` shows only `spec/translate_gpt_release_notes_action_spec.rb` modified (no production code, no fixtures)
- [ ] `bundle exec rubocop spec/translate_gpt_release_notes_action_spec.rb` reports no offenses
- [ ] `plans/README.md` status row for 002 updated

## STOP conditions

Stop and report back (do not improvise) if:

- Constructing `TranslateGptReleaseNotesHelper.new(...)` raises during the happy-path test even with `translate_text` stubbed (e.g. provider validation rejects the fake `api_token`). If so, report it — you may need to also stub `Fastlane::Helper::TranslateGptReleaseNotesHelper.new` to return a double; do not guess at length, surface the error.
- The "current nil-overwrite" characterization example does NOT show an empty file (i.e. the bug behaves differently than described) — the finding may have drifted; report what you observed instead.
- A new example requires editing production code to pass — that means it belongs in plan 003, not here.
- The full suite fails in files other than the one in scope.

## Maintenance notes

- These are **characterization** tests: Step 4 pins current buggy behavior on purpose. When plan 003 lands, the Step-4 example MUST be rewritten to assert the file is preserved and `last_successful_run.txt` is not written on failure. The `CHARACTERIZATION OF CURRENT BEHAVIOR` comment is the breadcrumb for that.
- Reviewer should confirm the temp-dir harness cleans up (no stray `fastlane/metadata` or `last_successful_run.txt` in the repo root after `bundle exec rspec`; check `git status`).
- Android-layout characterization (changelogs/`<version>.txt`) is deferred — iOS coverage is sufficient to gate plan 003; add Android cases later if the loop logic diverges.
