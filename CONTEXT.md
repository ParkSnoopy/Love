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

## Project Concepts

- `UserDataRepository`: SQLite persistence boundary for bookmarks, highlights, notes, and history.
- `notesProvider`: Riverpod async source for all saved notes used by the saved notes tab.
- `VerseActionPane`: bottom reader action surface for selected verses; owns copy, bookmark, highlight, note, and commentary actions.
- `BugReportLog`: in-memory session error buffer populated from `FlutterError`, `PlatformDispatcher`, and guarded-zone errors.
- `BugReporter`: builds the public GitHub issue URL and report body for the settings bug-report action.
- `SettingPage`: settings/support surface where users open the bug-report flow.
