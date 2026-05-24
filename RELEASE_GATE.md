Release gate checklist

Must pass before release:

1. Flutter analyze passes
   Command:
   flutter analyze

2. Full test suite passes
   Command:
   flutter test

3. Import validation UX works
   - Open Library
   - Tap "Validate Import"
   - On valid DB pack -> snackbar "Import validate OK"
   - On invalid DB pack:
     - debug build -> detailed ImportException text
     - release build -> generic "Import failed. Please check data pack."

4. Reader selection actions
   - Single: Clipboard/Share/Bookmark/Highlight/Note/View Commentary available in that order
   - Multi: same action order available
   - selected verses show outline markers
   - switching commentary fullscreen and back preserves reader and commentary scroll positions

5. Search pagination
   - LIKE search
   - 100 rows per page
   - infinite scroll loads more

6. User data persistence
   - user_data.db initialized
   - history capped at 50 latest rows
   - bookmark dedup by (book, chapter, verse)
   - note upsert by (book, chapter, verse)
   - bookmarks created together show as grouped ranges in Saved
   - notes saved together with identical content show as grouped ranges in Saved
   - tapping Saved entries opens Reader and scrolls without selecting verse text

7. Bible version picker
   - picker title uses "version" wording, not "translation"
   - Bible versions grouped by language in expandable sections
   - active language group opens by default
