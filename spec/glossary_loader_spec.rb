require 'tmpdir'
require 'json'
require 'fileutils'

describe Fastlane::Helper::GlossaryLoader do
  before do
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:warning)
    allow(Fastlane::UI).to receive(:error)
  end

  describe '#initialize' do
    it 'creates loader without glossary params' do
      loader = described_class.new(master_locale: 'en-US')
      expect(loader.terms_for('any text', 'fr')).to eq({})
    end

    it 'warns when glossary file not found' do
      expect(Fastlane::UI).to receive(:warning).with(/not found/)
      described_class.new(master_locale: 'en-US', glossary: '/nonexistent/file.json')
    end

    it 'warns when glossary directory not found' do
      expect(Fastlane::UI).to receive(:warning).with(/not found/)
      described_class.new(master_locale: 'en-US', glossary_dir: '/nonexistent/dir')
    end
  end

  describe 'curated JSON glossary' do
    let(:glossary_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(glossary_dir) }

    it 'loads terms from a valid JSON file' do
      glossary_file = File.join(glossary_dir, 'glossary.json')
      File.write(glossary_file, JSON.generate({
        "Home Screen" => { "fr" => "Ecran d'accueil", "de" => "Startbildschirm" },
        "Settings" => { "fr" => "Parametres", "de" => "Einstellungen" }
      }))

      loader = described_class.new(master_locale: 'en-US', glossary: glossary_file)

      result = loader.terms_for('Check out the new Home Screen', 'fr')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end

    it 'handles malformed JSON gracefully' do
      glossary_file = File.join(glossary_dir, 'bad.json')
      File.write(glossary_file, 'not valid json{')

      expect(Fastlane::UI).to receive(:error).with(/Failed to parse/)
      loader = described_class.new(master_locale: 'en-US', glossary: glossary_file)
      expect(loader.terms_for('any text', 'fr')).to eq({})
    end

    it 'skips non-hash translation values' do
      glossary_file = File.join(glossary_dir, 'glossary.json')
      File.write(glossary_file, JSON.generate({
        "Valid" => { "fr" => "Valide" },
        "Invalid" => "just a string"
      }))

      loader = described_class.new(master_locale: 'en-US', glossary: glossary_file)
      result = loader.terms_for('Valid and Invalid terms', 'fr')
      expect(result).to eq({ "Valid" => "Valide" })
    end
  end

  describe 'ARB format' do
    let(:arb_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(arb_dir) }

    it 'extracts glossary from ARB files' do
      File.write(File.join(arb_dir, 'app_en.arb'), JSON.generate({
        "@@locale" => "en",
        "homeScreen" => "Home Screen",
        "@homeScreen" => { "description" => "Title of home screen" },
        "settings" => "Settings"
      }))

      File.write(File.join(arb_dir, 'app_fr.arb'), JSON.generate({
        "@@locale" => "fr",
        "homeScreen" => "Ecran d'accueil",
        "@homeScreen" => { "description" => "Titre de l'ecran d'accueil" },
        "settings" => "Parametres"
      }))

      loader = described_class.new(master_locale: 'en', glossary_dir: arb_dir)

      result = loader.terms_for('New Home Screen design', 'fr')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end

    it 'handles locale codes with region (en-US)' do
      File.write(File.join(arb_dir, 'app_en-US.arb'), JSON.generate({
        "title" => "My App"
      }))

      File.write(File.join(arb_dir, 'app_fr.arb'), JSON.generate({
        "title" => "Mon App"
      }))

      loader = described_class.new(master_locale: 'en-US', glossary_dir: arb_dir)

      result = loader.terms_for('Welcome to My App', 'fr')
      expect(result).to eq({ "My App" => "Mon App" })
    end
  end

  describe 'Apple .strings format' do
    let(:strings_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(strings_dir) }

    it 'extracts glossary from .strings files' do
      en_dir = File.join(strings_dir, 'en.lproj')
      fr_dir = File.join(strings_dir, 'fr.lproj')
      FileUtils.mkdir_p(en_dir)
      FileUtils.mkdir_p(fr_dir)

      File.write(File.join(en_dir, 'Localizable.strings'), <<~STRINGS)
        /* Home screen title */
        "home_title" = "Home Screen";
        /* Settings */
        "settings_title" = "Settings";
      STRINGS

      File.write(File.join(fr_dir, 'Localizable.strings'), <<~STRINGS)
        /* Home screen title */
        "home_title" = "Ecran d'accueil";
        /* Settings */
        "settings_title" = "Parametres";
      STRINGS

      loader = described_class.new(master_locale: 'en', glossary_dir: strings_dir)

      result = loader.terms_for('Updated Home Screen with new features', 'fr')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end
  end

  describe 'Android strings.xml format' do
    let(:xml_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(xml_dir) }

    it 'extracts glossary from Android XML files' do
      values_dir = File.join(xml_dir, 'values')
      values_fr_dir = File.join(xml_dir, 'values-fr')
      FileUtils.mkdir_p(values_dir)
      FileUtils.mkdir_p(values_fr_dir)

      File.write(File.join(values_dir, 'strings.xml'), <<~XML)
        <?xml version="1.0" encoding="utf-8"?>
        <resources>
            <string name="home_title">Home Screen</string>
            <string name="settings_title">Settings</string>
        </resources>
      XML

      File.write(File.join(values_fr_dir, 'strings.xml'), <<~XML)
        <?xml version="1.0" encoding="utf-8"?>
        <resources>
            <string name="home_title">Ecran d'accueil</string>
            <string name="settings_title">Parametres</string>
        </resources>
      XML

      loader = described_class.new(master_locale: 'en-US', glossary_dir: xml_dir)

      result = loader.terms_for('Redesigned Home Screen', 'fr')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end
  end

  describe 'JSON i18n format' do
    let(:json_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(json_dir) }

    it 'extracts glossary from flat JSON files' do
      File.write(File.join(json_dir, 'en.json'), JSON.generate({
        "home.title" => "Home Screen",
        "settings.title" => "Settings"
      }))

      File.write(File.join(json_dir, 'fr.json'), JSON.generate({
        "home.title" => "Ecran d'accueil",
        "settings.title" => "Parametres"
      }))

      loader = described_class.new(master_locale: 'en', glossary_dir: json_dir)

      result = loader.terms_for('New Home Screen layout', 'fr')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end

    it 'flattens nested JSON structures' do
      File.write(File.join(json_dir, 'en.json'), JSON.generate({
        "home" => { "title" => "Home Screen" },
        "settings" => { "title" => "Settings" }
      }))

      File.write(File.join(json_dir, 'fr.json'), JSON.generate({
        "home" => { "title" => "Ecran d'accueil" },
        "settings" => { "title" => "Parametres" }
      }))

      loader = described_class.new(master_locale: 'en', glossary_dir: json_dir)

      result = loader.terms_for('Check the Home Screen', 'fr')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end
  end

  describe 'XLIFF format' do
    let(:xliff_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(xliff_dir) }

    it 'extracts glossary from XLIFF files' do
      File.write(File.join(xliff_dir, 'translations.xliff'), <<~XLIFF)
        <?xml version="1.0" encoding="UTF-8"?>
        <xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
          <file source-language="en" target-language="fr" datatype="plaintext">
            <body>
              <trans-unit id="home_title">
                <source>Home Screen</source>
                <target>Ecran d'accueil</target>
              </trans-unit>
              <trans-unit id="settings_title">
                <source>Settings</source>
                <target>Parametres</target>
              </trans-unit>
            </body>
          </file>
        </xliff>
      XLIFF

      loader = described_class.new(master_locale: 'en', glossary_dir: xliff_dir)

      result = loader.terms_for('Updated Home Screen', 'fr')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end
  end

  describe 'fuzzy matching' do
    let(:glossary_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(glossary_dir) }

    let(:loader) do
      glossary_file = File.join(glossary_dir, 'glossary.json')
      File.write(glossary_file, JSON.generate({
        "Home Screen" => { "fr" => "Ecran d'accueil" },
        "Settings" => { "fr" => "Parametres" },
        "Workout Tracker" => { "fr" => "Suivi d'entrainement" },
        "OK" => { "fr" => "OK" }
      }))
      described_class.new(master_locale: 'en-US', glossary: glossary_file)
    end

    it 'matches case-insensitively' do
      result = loader.terms_for('check the home screen now', 'fr')
      expect(result).to include("Home Screen" => "Ecran d'accueil")
    end

    it 'matches substring within text' do
      result = loader.terms_for('We redesigned the Home Screen for better UX', 'fr')
      expect(result).to include("Home Screen" => "Ecran d'accueil")
    end

    it 'matches when 2+ significant words from multi-word term appear in text' do
      result = loader.terms_for('New workout tracker features available', 'fr')
      expect(result).to include("Workout Tracker" => "Suivi d'entrainement")
    end

    it 'does not match when only 1 word from multi-word term appears' do
      result = loader.terms_for('New workout features available', 'fr')
      expect(result).not_to include("Workout Tracker")
    end

    it 'does not match short words individually' do
      result = loader.terms_for('Press OK to continue', 'fr')
      expect(result).not_to include("OK")
    end

    it 'does not match terms exceeding max length' do
      glossary_file = File.join(glossary_dir, 'long_terms.json')
      File.write(glossary_file, JSON.generate({
        "This is a very long sentence that should not be used as a glossary term because it is way too long for practical purposes" => { "fr" => "Translation" }
      }))
      long_loader = described_class.new(master_locale: 'en-US', glossary: glossary_file)
      result = long_loader.terms_for('This is a very long sentence that should not be used as a glossary term because it is way too long for practical purposes', 'fr')
      expect(result).to be_empty
    end

    it 'returns only matching terms' do
      result = loader.terms_for('Home Screen update', 'fr')
      expect(result.keys).to eq(["Home Screen"])
    end

    it 'returns empty hash when no terms match' do
      result = loader.terms_for('Bug fixes and improvements', 'fr')
      expect(result).to eq({})
    end
  end

  describe 'locale matching' do
    let(:glossary_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(glossary_dir) }

    it 'matches normalized locale codes (fr matches fr-FR)' do
      glossary_file = File.join(glossary_dir, 'glossary.json')
      File.write(glossary_file, JSON.generate({
        "Settings" => { "fr" => "Parametres" }
      }))

      loader = described_class.new(master_locale: 'en-US', glossary: glossary_file)
      result = loader.terms_for('New Settings page', 'fr-FR')
      expect(result).to eq({ "Settings" => "Parametres" })
    end

    it 'prefers exact locale match over normalized' do
      glossary_file = File.join(glossary_dir, 'glossary.json')
      File.write(glossary_file, JSON.generate({
        "Color" => { "en-GB" => "Colour", "en" => "Color" }
      }))

      loader = described_class.new(master_locale: 'en-US', glossary: glossary_file)
      result = loader.terms_for('New Color picker', 'en-GB')
      expect(result).to eq({ "Color" => "Colour" })
    end
  end

  describe 'cross-format locale normalization' do
    let(:tmp_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(tmp_dir) }

    it 'handles fastlane en-US with ARB app_en.arb (no region)' do
      File.write(File.join(tmp_dir, 'app_en.arb'), JSON.generate({
        "title" => "Home Screen"
      }))
      File.write(File.join(tmp_dir, 'app_fr.arb'), JSON.generate({
        "title" => "Ecran d'accueil"
      }))

      loader = described_class.new(master_locale: 'en-US', glossary_dir: tmp_dir)
      result = loader.terms_for('New Home Screen', 'fr')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end

    it 'handles fastlane en_US (underscore) with ARB app_en.arb' do
      File.write(File.join(tmp_dir, 'app_en.arb'), JSON.generate({
        "title" => "Settings"
      }))
      File.write(File.join(tmp_dir, 'app_de.arb'), JSON.generate({
        "title" => "Einstellungen"
      }))

      loader = described_class.new(master_locale: 'en_US', glossary_dir: tmp_dir)
      result = loader.terms_for('New Settings page', 'de')
      expect(result).to eq({ "Settings" => "Einstellungen" })
    end

    it 'handles fastlane fr-FR target with glossary stored as fr' do
      File.write(File.join(tmp_dir, 'app_en.arb'), JSON.generate({
        "title" => "Home Screen"
      }))
      File.write(File.join(tmp_dir, 'app_fr.arb'), JSON.generate({
        "title" => "Ecran d'accueil"
      }))

      loader = described_class.new(master_locale: 'en', glossary_dir: tmp_dir)
      result = loader.terms_for('New Home Screen', 'fr-FR')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end

    it 'handles fastlane pt_BR (underscore) target with ARB pt-BR (hyphen)' do
      File.write(File.join(tmp_dir, 'app_en.arb'), JSON.generate({
        "title" => "Settings"
      }))
      File.write(File.join(tmp_dir, 'app_pt-BR.arb'), JSON.generate({
        "title" => "Configuracoes"
      }))

      loader = described_class.new(master_locale: 'en', glossary_dir: tmp_dir)
      result = loader.terms_for('New Settings', 'pt_BR')
      expect(result).to eq({ "Settings" => "Configuracoes" })
    end

    it 'handles Android values-en-rUS resource qualifier' do
      values_dir = File.join(tmp_dir, 'values')
      values_fr_dir = File.join(tmp_dir, 'values-fr-rFR')
      FileUtils.mkdir_p(values_dir)
      FileUtils.mkdir_p(values_fr_dir)

      File.write(File.join(values_dir, 'strings.xml'), <<~XML)
        <?xml version="1.0" encoding="utf-8"?>
        <resources>
            <string name="title">Home Screen</string>
        </resources>
      XML

      File.write(File.join(values_fr_dir, 'strings.xml'), <<~XML)
        <?xml version="1.0" encoding="utf-8"?>
        <resources>
            <string name="title">Ecran d'accueil</string>
        </resources>
      XML

      loader = described_class.new(master_locale: 'en-US', glossary_dir: tmp_dir)
      # fr-rFR canonicalizes to fr-fr, lookup with fr-FR also canonicalizes to fr-fr
      result = loader.terms_for('New Home Screen', 'fr-FR')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end

    it 'handles iOS .strings with en_US.lproj and fastlane en-US' do
      en_dir = File.join(tmp_dir, 'en_US.lproj')
      fr_dir = File.join(tmp_dir, 'fr_FR.lproj')
      FileUtils.mkdir_p(en_dir)
      FileUtils.mkdir_p(fr_dir)

      File.write(File.join(en_dir, 'Localizable.strings'), <<~STRINGS)
        "title" = "Home Screen";
      STRINGS

      File.write(File.join(fr_dir, 'Localizable.strings'), <<~STRINGS)
        "title" = "Ecran d'accueil";
      STRINGS

      loader = described_class.new(master_locale: 'en-US', glossary_dir: tmp_dir)
      result = loader.terms_for('New Home Screen', 'fr-FR')
      expect(result).to eq({ "Home Screen" => "Ecran d'accueil" })
    end

    it 'handles glossary JSON with mixed locale formats' do
      glossary_file = File.join(tmp_dir, 'glossary.json')
      File.write(glossary_file, JSON.generate({
        "Settings" => { "fr_FR" => "Parametres", "de-DE" => "Einstellungen" }
      }))

      loader = described_class.new(master_locale: 'en-US', glossary: glossary_file)

      # fr-FR lookup matches fr_FR entry (both canonicalize to fr-fr)
      result_fr = loader.terms_for('New Settings', 'fr-FR')
      expect(result_fr).to eq({ "Settings" => "Parametres" })

      # de_DE lookup matches de-DE entry (both canonicalize to de-de)
      result_de = loader.terms_for('New Settings', 'de_DE')
      expect(result_de).to eq({ "Settings" => "Einstellungen" })
    end
  end

  describe 'integration: real timer-coffee ARB data' do
    let(:fixtures_dir) { File.expand_path('fixtures/timer-coffee', __dir__) }
    let(:l10n_dir) { File.join(fixtures_dir, 'l10n') }

    let(:release_notes_ios) do
      File.read(File.join(fixtures_dir, 'ios_fastlane', 'metadata', 'en-US', 'release_notes.txt'))
    end

    before do
      skip 'timer-coffee fixtures not available' unless Dir.exist?(l10n_dir)
    end

    it 'loads real ARB files without errors' do
      loader = described_class.new(master_locale: 'en', glossary_dir: l10n_dir)
      expect(loader).to be_a(described_class)
    end

    it 'extracts relevant terms from real release notes for French' do
      loader = described_class.new(master_locale: 'en', glossary_dir: l10n_dir)
      result = loader.terms_for(release_notes_ios, 'fr')

      # Should find some terms but not the entire glossary
      expect(result).not_to be_empty
      expect(result.size).to be < 100 # Fuzzy filtering keeps it small
    end

    it 'extracts relevant terms from real release notes for German' do
      loader = described_class.new(master_locale: 'en', glossary_dir: l10n_dir)
      result = loader.terms_for(release_notes_ios, 'de')

      expect(result).not_to be_empty
      expect(result.size).to be < 100
    end

    it 'returns consistent terms across multiple calls' do
      loader = described_class.new(master_locale: 'en', glossary_dir: l10n_dir)
      result1 = loader.terms_for(release_notes_ios, 'fr')
      result2 = loader.terms_for(release_notes_ios, 'fr')

      expect(result1).to eq(result2)
    end

    it 'returns different terms for different target locales' do
      loader = described_class.new(master_locale: 'en', glossary_dir: l10n_dir)
      result_fr = loader.terms_for(release_notes_ios, 'fr')
      result_de = loader.terms_for(release_notes_ios, 'de')

      # Source terms should be the same, translations should differ
      expect(result_fr.keys).to eq(result_de.keys)
      expect(result_fr.values).not_to eq(result_de.values)
    end

    it 'handles locale variations (fr vs fr-FR vs fr_FR)' do
      loader = described_class.new(master_locale: 'en', glossary_dir: l10n_dir)
      result_fr = loader.terms_for(release_notes_ios, 'fr')
      result_fr_fr = loader.terms_for(release_notes_ios, 'fr-FR')
      result_fr_fr_us = loader.terms_for(release_notes_ios, 'fr_FR')

      # All should resolve to the same French translations
      expect(result_fr).to eq(result_fr_fr)
      expect(result_fr).to eq(result_fr_fr_us)
    end

    it 'returns empty hash for source text with no matching terms' do
      loader = described_class.new(master_locale: 'en', glossary_dir: l10n_dir)
      result = loader.terms_for('Simple bug fixes.', 'fr')

      # Very short generic text unlikely to match app-specific terminology
      expect(result).to be_a(Hash)
    end

    it 'does not include the full ARB file content (filtering works)' do
      loader = described_class.new(master_locale: 'en', glossary_dir: l10n_dir)
      result = loader.terms_for(release_notes_ios, 'fr')

      # ARB has 1200+ lines, result should be much smaller
      expect(result.size).to be < 50
    end
  end

  describe 'combined glossary (file + directory)' do
    let(:tmp_dir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(tmp_dir) }

    it 'merges terms from both sources' do
      glossary_file = File.join(tmp_dir, 'glossary.json')
      File.write(glossary_file, JSON.generate({
        "Settings" => { "fr" => "Parametres" }
      }))

      arb_dir = File.join(tmp_dir, 'l10n')
      FileUtils.mkdir_p(arb_dir)
      File.write(File.join(arb_dir, 'app_en.arb'), JSON.generate({
        "homeScreen" => "Home Screen"
      }))
      File.write(File.join(arb_dir, 'app_fr.arb'), JSON.generate({
        "homeScreen" => "Ecran d'accueil"
      }))

      loader = described_class.new(
        master_locale: 'en',
        glossary: glossary_file,
        glossary_dir: arb_dir
      )

      result = loader.terms_for('Home Screen and Settings updated', 'fr')
      expect(result).to eq({
        "Home Screen" => "Ecran d'accueil",
        "Settings" => "Parametres"
      })
    end

    it 'curated file takes precedence over directory' do
      glossary_file = File.join(tmp_dir, 'glossary.json')
      File.write(glossary_file, JSON.generate({
        "Home Screen" => { "fr" => "Page d'accueil" }
      }))

      arb_dir = File.join(tmp_dir, 'l10n')
      FileUtils.mkdir_p(arb_dir)
      File.write(File.join(arb_dir, 'app_en.arb'), JSON.generate({
        "homeScreen" => "Home Screen"
      }))
      File.write(File.join(arb_dir, 'app_fr.arb'), JSON.generate({
        "homeScreen" => "Ecran d'accueil"
      }))

      loader = described_class.new(
        master_locale: 'en',
        glossary: glossary_file,
        glossary_dir: arb_dir
      )

      result = loader.terms_for('Home Screen update', 'fr')
      # Curated file value wins because it's loaded first and directory doesn't overwrite
      expect(result["Home Screen"]).to eq("Page d'accueil")
    end
  end
end
