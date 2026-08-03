# Changelog

## 2026-08-03

### Add

- Add a reader information action that opens the current book description when the selected commentary provides one.

### Change

- Move previous- and next-chapter actions from the reader top bar to floating controls above the bottom router bar.
- Change the light theme colors to the warm cream, coral, and ink palette from `Design_Claude_General.md` without changing layout or component design.
- Upgrade `archive` from major version 3 to 4 and refresh compatible locked Flutter package versions.

### Fix

- Fix settings bug reports opening the retired `Love.pub` issue tracker instead of the `Love` repository.

## 2026-07-19

### Add

- Add full-chapter search using book names or Korean canonical abbreviations, including `창세기 26장`, `창 26`, `삿 21`, `삼상 26`, and `삼하 24`; bare `삼` searches both Samuel books.

### Change

- Change the reader chat-bubble action to show saved memos beneath their verses.
- Change Android, iOS, macOS, web, and Windows app icons to ImageMagick conversions generated from `image.png`.

### Fix

- Fix all release workflows restoring the public asset archive with an unnecessary authorization header.

### Remove

- Remove the inactive share action from the verse action pane.

## 2026-07-03

### Add

- Add settings bug report action that opens a GitHub issue with recent captured error logs prefilled.

### Fix

- Reload existing single-verse note content when reopening the note dialog.
