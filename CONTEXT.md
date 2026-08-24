# Context

## Vocabulary

- `add note`: reader action pane full-page editor opened from a selected verse or verse range; its upper third is a selected-verse reader and its lower area is the note editor.
- `write note`: first-time full-page note creation flow from the reader selection action pane.
- `add note again`: reopening the same reader note editor after saving; if exactly one verse is displayed as selected, the saved note content should prefill.
- `notes tab`: saved study-data screen that lists persisted notes from SQLite via `notesProvider` / `UserDataRepository.loadAllNotes`.
- `previous note is not showing on screen`: editor prefill/rendering problem, not necessarily persistence failure, especially when the note is visible in the notes tab.
- `selection`: Riverpod `verseSelectionProvider`; can be single or multi mode. A one-verse multi-selection is still one editable verse for note prefill.
- `bug report`: user-facing settings support action for reporting app problems to GitHub Issues.
- `check update`: support action immediately before Report a bug; compares the build-time commit hash with the latest GitHub release `target_commitish`, reports when the build is current, and shows an update dialog linking to that release when they differ.
- `github issue`: bug-report target at `https://github.com/ParkSnoopy/Love/issues/new`.
- `error log`: in-app captured Flutter/platform/zone exception summaries and stack traces for the current session; safe report body material that users can review/remove before submitting.
- `automatically attach`: prefill the GitHub issue body with captured logs and copy the same body to clipboard; GitHub new-issue URLs cannot attach files directly.
- `book and chapter search`: a search query ending in a chapter number, such as `창세기 26장`, `창 26`, `삿 21`, `삼상 26`, `삼하 24`, or `Genesis 26`; resolves canonical Korean abbreviations, exact names, or unambiguous name prefixes and returns every verse in that chapter. Bare `삼` searches both Samuel books, while `삼상` and `삼하` select one.
- `reader chat bubble`: reader app-bar action defaults to showing saved verse memos with an outlined chat-bubble icon; hiding memos uses a crossed chat-bubble icon. It no longer toggles commentary.
- `memo under corresponding verse`: note content from `notesProvider`, anchored on the final verse and rendered directly below it with Markdown-style left rules. A multi-verse memo also persists its first verse so every noted verse receives the same vertical left rule.
- `application themes`: the theme sheet offers System, Light Orange, Light Green, Dark Orange, Dark Purple, and Custom. Custom stores one explicit Light or Dark base plus one opaque primary-color ID selected from the application palette; Apply persists all three values together, while Cancel leaves the active theme unchanged. Its light base preserves Light Orange surfaces, its dark base preserves Dark Purple surfaces, and primary foreground/container roles are contrast-derived. Generic Light and Dark themes are not exposed.
- `reader typography`: reader settings persist font size, named font style, line spacing, and UI scale. The discrete slider exposes each face available in the selected Sans or Serif Super OTC. Because Flutter's asset loader opens only TTC face zero, the app extracts the selected face in memory from the two original TTC assets and registers it dynamically; no split font files are stored. The selected face applies to reader, search, and commentary text, except highlighted verses remain bold.
- `highlights`: overlapping highlights replace the selected range while adjacent ranges of the same color are automatically concatenated.
- `app icon`: `image.png` is the canonical 1024×1024 source; ImageMagick generates opaque platform sizes for Android, iOS, macOS, web, and Windows, plus safe-margin web maskable icons.
- `workflow builds are failing`: release jobs failing at `Restore assets archive` because the public GitHub release download was sent an authorization header; restore without credentials.
- `chapter navigation controls`: flat opaque circular previous/next buttons at the reader's bottom-left and bottom-right on a transparent overlay immediately above the shared router bar; the bold book/chapter label is 20 px and reader content reserves the overlay height so bottom text remains unobscured.
- `book information action`: reader top-bar information button enabled only when the active commentary contains a non-empty introduction at `book_id = current book`, `chapter = 0`, `verse = 0`; opens that book description directly.
- `light theme`: color-only warm editorial palette based on `Design_Claude_General.md`, using cream surfaces, coral primary actions, and warm ink text while preserving existing component design.
- `dependency upgrades`: use `flutter pub upgrade --major-versions`; direct dependencies currently resolve at their newest compatible major versions, with Flutter SDK constraints governing newer transitive-only releases.
- `rolling release`: one root workflow builds Linux, macOS, Windows, and Android, then moves one dated rolling tag and publishes one latest non-prerelease with assets named `Love-v<app version>-d<data version>.<platform extension>`.
- `app data backup`: settings action that exports preferences, reading position, bookmarks, highlights, notes, and history to a validated `.lovebackup` archive; `AppDataBackupParser` owns archive parsing, and import replaces current study data only after confirmation and database validation. Import creates the latest default configuration, overlays the current local configuration, then overlays the selected backup configuration before atomically applying the result. `AppConfigurationParser` is the single parser and ordered-overlay boundary shared by normal preference loading, backup import, and app-update migration. Production import treats missing supported metadata and database schema fields as legacy data, completing them with current defaults before replacement; malformed archives and corrupted databases remain rejected. Every regular file anywhere under `backup/` is regression-tested against the latest importer without extension filtering.
- `Korean Bible order`: Bible selection strips whitespace before ranking, then lists `개역개정판`, `개역개정 4판`, and `우리말 성경` before all other Korean translations.
- `backup files`: exports use platform-native destinations; imports allow any selected file on every platform and validate its bytes as a Love backup before applying it. Android exports save directly to the public Downloads collection and imports use the unrestricted system content picker.
- `app configuration update`: once per installed app version, startup creates the latest default configuration, overlays every valid scalar value from the local configuration, replaces the local file with that complete result, and records the migrated app version separately from user preferences.

## Project Concepts

- `UserDataRepository`: SQLite persistence boundary for bookmarks, highlights, notes, and history.
- `notesProvider`: Riverpod async source for all saved notes used by the saved notes tab.
- `VerseActionPane`: bottom reader action surface for selected verses; owns copy, bookmark, highlight, note, and commentary actions.
- `SearchRepository`: resolves book/chapter references before falling back to verse-text `LIKE` search.
- `BugReportLog`: in-memory session error buffer populated from `FlutterError`, `PlatformDispatcher`, and guarded-zone errors.
- `BugReporter`: builds the public GitHub issue URL and report body for the settings bug-report action.
- `SettingPage`: settings/support surface where users open the bug-report flow.
- `.assets-uri`: source of the public release archive containing ignored databases and fonts required before Flutter builds.
