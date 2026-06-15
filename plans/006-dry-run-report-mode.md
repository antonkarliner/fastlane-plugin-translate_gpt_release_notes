# Plan 006: A `dry_run` mode previews translations without writing files

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 0ce8cd9..HEAD -- lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb spec/translate_gpt_release_notes_action_spec.rb README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S–M
- **Risk**: LOW
- **Depends on**: plans/002-action-orchestration-tests.md (reuses its `with_ios_metadata` test harness); strongly recommended after plans/003 (so dry-run shares the same success/skip semantics)
- **Category**: direction (feature)
- **Planned at**: commit `0ce8cd9`, 2026-06-15

## Why this matters

This plugin writes directly into a user's `fastlane/metadata` tree, and a single bad run can overwrite many locale files (the data-loss risk plan 003 addresses). Adopting it in CI is safer if there's a way to see *what would happen* first. A `dry_run` option that performs the translations, prints a per-locale preview and character count (including whether each translation fits the Android 500-char limit), but writes nothing and does not touch `last_successful_run.txt`, gives users a trustworthy "what will this do" check. It's a small, self-contained feature with high trust value and no change to the default behavior.

## Current state

- `lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb`.

The end of `run` (lines 54–63), where writing happens:

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

The `available_options` array (lines 116–253) defines every `FastlaneCore::ConfigItem`. The Android limit constant `ANDROID_CHAR_LIMIT = 500` lives in `helper/providers/base_provider.rb:9`.

### Conventions to match

- New options are `FastlaneCore::ConfigItem.new(...)` entries appended to `available_options`. Boolean options use `type: Boolean` (Fastlane provides `Boolean`) — see how `is_string`/`type:` are used in the existing items. For a boolean flag use:
  ```ruby
  FastlaneCore::ConfigItem.new(
    key: :dry_run,
    env_name: "TRANSLATE_DRY_RUN",
    description: "Preview translations without writing files",
    type: Boolean,
    optional: true,
    default_value: false
  )
  ```
- User output uses `UI.message` / `UI.important` / `UI.warning`.
- Tests build temp metadata trees via the `with_ios_metadata` helper added in plan 002.

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
- `spec/translate_gpt_release_notes_action_spec.rb`
- `README.md` (document the new option)

**Out of scope** (do NOT touch):
- Provider files — dry-run still calls providers normally (it previews real output); only the write step changes.
- `base_provider.rb` — read `ANDROID_CHAR_LIMIT` only; reference the literal `500` in the action or read the constant, but do not modify it.

## Git workflow

- Branch: `advisor/006-dry-run-mode`
- Commit style: plain imperative subject (e.g. "Add dry_run mode to preview translations"). No `Co-Authored-By` trailer.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add the `dry_run` ConfigItem

Append the `:dry_run` ConfigItem (shown in Current state → Conventions) to the `available_options` array, after the existing items.

**Verify**: `ruby -e "require './lib/fastlane/plugin/translate_gpt_release_notes'; puts Fastlane::Actions::TranslateGptReleaseNotesAction.available_options.map(&:key).include?(:dry_run)"` → prints `true`.

### Step 2: Branch the write step on `dry_run`

In `run`, after building `translated_texts`, branch instead of always writing:

```ruby
if params[:dry_run]
  print_dry_run_preview(translated_texts, params)
else
  update_translated_texts(base_directory, translated_texts, is_ios, params)

  any_success = translated_texts.any? { |locale, text| locale != params[:master_locale] && !text.nil? && !text.to_s.strip.empty? }
  if any_success
    File.write(last_run_file, Time.now.to_i)
  else
    UI.error("No translations succeeded; not updating #{last_run_file} so the next run will retry.")
  end
end
```

> Note: if plan 003 has already landed, the `else` branch above will already exist in that form — keep it as-is and just wrap it with the `if params[:dry_run]` branch. If plan 003 has NOT landed, the current code is the unconditional `update_translated_texts` + `File.write` pair; wrap that. Either way, dry-run must not call `update_translated_texts` and must not write `last_run_file`.

Then add the preview method:

```ruby
def self.print_dry_run_preview(translated_texts, params)
  android_limit = 500 # Google Play hard limit; see BaseProvider::ANDROID_CHAR_LIMIT
  UI.important("DRY RUN: no files will be written.")
  translated_texts.each do |locale, text|
    next if locale == params[:master_locale]

    if text.nil? || text.to_s.strip.empty?
      UI.warning("  #{locale}: translation FAILED (would be skipped)")
      next
    end

    length = text.length
    over = params[:platform] == 'android' && length > android_limit
    suffix = over ? " — EXCEEDS #{android_limit}-char Android limit" : ""
    UI.message("  #{locale}: #{length} chars#{suffix}")
  end
end
```

**Verify**: `grep -n "print_dry_run_preview\|DRY RUN" lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` → matches present.

### Step 3: Test dry-run writes nothing

Add to `spec/translate_gpt_release_notes_action_spec.rb` (reusing `with_ios_metadata`):

```ruby
context 'dry_run mode' do
  it 'does not write any target files and does not record a run' do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:important)
    allow(Fastlane::UI).to receive(:warning)
    allow_any_instance_of(Fastlane::Helper::TranslateGptReleaseNotesHelper)
      .to receive(:translate_text) { |_inst, _t, locale, _p| "translated-#{locale}" }

    with_ios_metadata do
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(
        provider: 'openai', platform: 'ios', master_locale: 'en-US', api_token: 'x', dry_run: true
      )

      expect(File.exist?('fastlane/metadata/fr-FR/release_notes.txt')).to be false
      expect(File.exist?('last_successful_run.txt')).to be false
    end
  end

  it 'still calls the provider to produce the preview' do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:important)
    called = false
    allow_any_instance_of(Fastlane::Helper::TranslateGptReleaseNotesHelper)
      .to receive(:translate_text) { called = true; 'x' }

    with_ios_metadata do
      Fastlane::Actions::TranslateGptReleaseNotesAction.run(
        provider: 'openai', platform: 'ios', master_locale: 'en-US', api_token: 'x', dry_run: true
      )
      expect(called).to be true
    end
  end
end
```

**Verify**: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → all pass.

### Step 4: Document in README

Add a short subsection under "Core Options" (the options table near README line 282) — add a `dry_run` row — and a brief "Dry Run" usage note. Example row:

```
| `dry_run` | Preview translations and character counts without writing files | `TRANSLATE_DRY_RUN` | `false` |
```

**Verify**: `grep -n "dry_run" README.md` → at least one match.

### Step 5: Run the full suite and lint

**Verify**:
- `bundle exec rspec` → 0 failures.
- `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` → no offenses.

## Test plan

- Tests in `spec/translate_gpt_release_notes_action_spec.rb` using the plan-002 harness.
- Cases: dry-run writes no files and no run record; dry-run still invokes the provider.
- Verification: `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `available_options` includes `:dry_run` (Step 1 verify command prints `true`)
- [ ] `grep -n "print_dry_run_preview" lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` → matches
- [ ] `grep -n "dry_run" README.md` → at least one match
- [ ] `bundle exec rspec spec/translate_gpt_release_notes_action_spec.rb` exits 0, all pass
- [ ] `bundle exec rspec` exits 0, 0 failures
- [ ] `bundle exec rubocop lib/fastlane/plugin/translate_gpt_release_notes/actions/translate_gpt_release_notes_action.rb` → no offenses
- [ ] `git status` shows only the three in-scope files modified
- [ ] `plans/README.md` status row for 006 updated

## STOP conditions

Stop and report back (do not improvise) if:

- `Boolean` is not defined when the gem loads `available_options` (some fastlane versions need it referenced differently). If `available_options` raises, report the error — do not guess at the type.
- Plan 002's `with_ios_metadata` helper does not exist in the spec — this plan reuses it; report the missing dependency rather than recreating the harness.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- If plan 003 lands after this one, ensure the non-dry-run `else` branch matches plan 003's success-tracking logic (don't leave two divergent copies of the write/record logic).
- The preview hardcodes `500` with a comment pointing at `BaseProvider::ANDROID_CHAR_LIMIT`. If that constant ever changes, update the comment/value (or refactor to read the constant directly).
- Reviewer should confirm dry-run truly writes nothing: the test asserts both no target file and no `last_successful_run.txt`.
