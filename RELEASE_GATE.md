Release gate checklist

Must pass before release:

1. Flutter analyze passes
   Command:
   /root/flutter/bin/flutter analyze

2. Full test suite passes
   Command:
   /root/flutter/bin/flutter test

3. Import validation UX works
   - Open Library
   - Tap "Validate Import"
   - On valid DB pack -> snackbar "Import validate OK"
   - On invalid DB pack:
     - debug build -> detailed ImportException text
     - release build -> generic "Import failed. Please check data pack."

4. Reader selection actions
   - Single: Copy/Share/Bookmark/Highlight/Note/Jump Comment available
   - Multi: Note + Jump Comment disabled

5. Search pagination
   - LIKE search
   - 100 rows per page
   - infinite scroll loads more

6. User data persistence
   - user_data.db initialized
   - history capped at 50 latest rows
   - bookmark dedup by (book, chapter, verse)
   - note upsert by (book, chapter, verse)
