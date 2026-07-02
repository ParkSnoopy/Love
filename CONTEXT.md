# Context

## Vocabulary

- `add note`: reader action pane note dialog opened from a selected verse or verse range.
- `write note`: first-time note creation flow from the reader selection action pane.
- `add note again`: reopening the same reader note dialog after saving; if exactly one verse is displayed as selected, the saved note content should prefill.
- `notes tab`: saved study-data screen that lists persisted notes from SQLite via `notesProvider` / `UserDataRepository.loadAllNotes`.
- `previous note is not showing on screen`: dialog prefill/rendering problem, not necessarily persistence failure, especially when the note is visible in the notes tab.
- `selection`: Riverpod `verseSelectionProvider`; can be single or multi mode. A one-verse multi-selection is still one editable verse for note prefill.

## Project Concepts

- `UserDataRepository`: SQLite persistence boundary for bookmarks, highlights, notes, and history.
- `notesProvider`: Riverpod async source for all saved notes used by the saved notes tab.
- `VerseActionPane`: bottom reader action surface for selected verses; owns copy, bookmark, highlight, note, and commentary actions.
