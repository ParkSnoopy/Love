# Context

## Vocabulary

- `add note`: reader action pane note dialog opened from a selected verse or verse range.
- `write note`: first-time note creation flow from the reader selection action pane.
- `add note again`: reopening the same reader note dialog after saving; if exactly one verse is displayed as selected, the saved note content should prefill.
- `notes tab`: saved study-data screen that lists persisted notes from SQLite via `notesProvider` / `UserDataRepository.loadAllNotes`.
- `previous note is not showing on screen`: dialog prefill/rendering problem, not necessarily persistence failure, especially when the note is visible in the notes tab.
- `selection`: Riverpod `verseSelectionProvider`; can be single or multi mode. A one-verse multi-selection is still one editable verse for note prefill.
- `bug report`: user-facing settings support action for reporting app problems to GitHub Issues.
- `github issue`: public release feedback target at `https://github.com/ParkSnoopy/Love.pub/issues/new`, not the source repository issue tracker.
- `error log`: in-app captured Flutter/platform/zone exception summaries and stack traces for the current session; safe report body material that users can review/remove before submitting.
- `automatically attach`: prefill the GitHub issue body with captured logs and copy the same body to clipboard; GitHub new-issue URLs cannot attach files directly.
- `book and chapter search`: a search query ending in a chapter number, such as `창세기 26장`, `창 26`, `삿 21`, `삼상 26`, `삼하 24`, or `Genesis 26`; resolves canonical Korean abbreviations, exact names, or unambiguous name prefixes and returns every verse in that chapter. Bare `삼` searches both Samuel books, while `삼상` and `삼하` select one.
- `reader chat bubble`: reader app-bar action that toggles saved verse memos inline beneath their corresponding verses; it no longer toggles commentary.
- `memo under corresponding verse`: note content from `notesProvider`, keyed by book, chapter, and verse and rendered directly below that verse while memo display is enabled.
- `app icon`: `image.png` is the canonical 1024×1024 source; ImageMagick generates opaque platform sizes for Android, iOS, macOS, web, and Windows, plus safe-margin web maskable icons.
- `workflow builds are failing`: release jobs failing at `Restore assets archive` because the public GitHub release download was sent an authorization header; restore without credentials.

## Project Concepts

- `UserDataRepository`: SQLite persistence boundary for bookmarks, highlights, notes, and history.
- `notesProvider`: Riverpod async source for all saved notes used by the saved notes tab.
- `VerseActionPane`: bottom reader action surface for selected verses; owns copy, bookmark, highlight, note, and commentary actions.
- `SearchRepository`: resolves book/chapter references before falling back to verse-text `LIKE` search.
- `BugReportLog`: in-memory session error buffer populated from `FlutterError`, `PlatformDispatcher`, and guarded-zone errors.
- `BugReporter`: builds the public GitHub issue URL and report body for the settings bug-report action.
- `SettingPage`: settings/support surface where users open the bug-report flow.
- `.assets-uri`: source of the public release archive containing ignored databases and fonts required before Flutter builds.
