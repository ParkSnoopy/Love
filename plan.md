# Bible App Implementation Plan (Flutter + Drift, Offline, Strict Validation)

This document details the architecture, design choices, data contracts, and implementation guidelines for reproducing this Bible application. It has been updated to reflect the completed development, emphasizing offline database pre-processing to minimize runtime overhead.

---

## 0) Locked Product Decisions

1. **Platform**: Flutter-first (cross-platform native and web support).
2. **Scope**: Reader-first user experience combined with essential study tools.
3. **Data Packaging**: Bundled `assets/data.zip` containing pre-processed databases. Assets are extracted to client storage on demand.
4. **Commentary Integration**: User selects a commentary database corresponding to the active Bible translation.
5. **Commentary Data Strategy (Pre-processed Sparse Schema)**: Commentaries are pre-migrated offline to use the exact same schema as Bibles. This eliminates runtime regex reference parsing, isolate mapping overhead, and database parsing errors on client devices.
6. **Reader Navigation**: Persistent book/chapter picker, swipe gestures for chapter transitions, and tap/long-press actions on verses.
7. **Position Persistence**: Active book and chapter are stored in persistent local storage. When switching Bibles, the position is clamped to the new database boundaries (max book/chapter).
8. **Commentary Toggle**: A dedicated visibility toggle allows users to show or hide the commentary pane without losing their active selection or having to re-select the database.
9. **Introduction & Preface Viewer**: General prefaces and book introductions are fully preserved in the database. A dedicated picker and styled viewer allow readers to inspect these materials directly from the selection screen or active pane.
10. **Study Tools**: Three-color highlights, bookmarks, editable verse notes, and a recent history list capped at 50 entries.
11. **Storage Separation**: System data (Bibles and commentaries) remains read-only. All user state (bookmarks, notes, history) is written to a separate SQLite database.
12. **Search Implementation**: Debounced text search utilizing SQL wildcard operators with page-offset pagination. Min-length limits are applied based on writing system (longer for Latin scripts, shorter for CJK characters).
13. **Theme & Typography**: Claude-inspired color palette supporting light, dark, and system-defined appearance. Typography relies strictly on local fonts to ensure complete offline usability.

---

## 1) System Architecture

### 1.1 Storage Zones

The application manages data across three distinct zones:
- **Bundled Assets (Read-Only)**: `assets/data.zip` containing the compressed databases, alongside local font files.
- **Imported Sandbox (Read-Only client-side)**: Extracted SQLite files for active Bible translations and commentary packs.
- **User Database (Writeable)**: A standalone `user_data.db` file containing user state, history, bookmarks, notes, and application preferences.

### 1.2 Database Schema & Data Contracts

To maintain schema uniformity and enable direct SQLite index lookups, both Bible and commentary databases implement the following schema.

#### Tables
- **`version`**: Metadata containing the slug identifier and the display label.
- **`books`**: Registry of books within the translation. Contains book ID, OSIS identifier, English name, native language name, testament category, and total chapter count.
- **`verses`**: The text content indexed by book ID, chapter, and verse.

#### Index
- **`idx_v_bc`**: Index defined on `verses(book_id, chapter)` to optimize reader lookups.

#### View
- **`indexing`**: Virtual table joining books and version details to expose metadata to the application layer.

### 1.3 Commentary Data Mapping Rules (Sparse Schema)

Instead of a complex relational mapping database, commentaries map directly to the `verses` table schema:
- **General Prefaces / Author Introductions**: Mapped under a dummy book `book_id = 0` (OSIS: `INTRO`, English Name: `General Intro`, Native Name: `일반 서론/소개`). Content is indexed under `chapter = 0` with sequential verse numbers (`verse = 1, 2, 3...`).
- **Book-level Introductions / Background Details**: Saved under `book_id = X` (where X is the canonical book ID), `chapter = 0`, and `verse = 0`.
- **Chapter-level Commentaries**: Written under `book_id = X`, `chapter = Y`, and `verse = 0`.
- **Verse-specific Comments**: Written under `book_id = X`, `chapter = Y`, and `verse = Z` (for commentaries that target specific verses).

---

## 2) Offline Database Migration (Pre-computation Process)

To avoid heavy text processing on client devices, a preprocessing script converts raw commentaries into the unified sparse schema.

### 2.1 Regex Validation & Author Name Protection
- During extraction, regex patterns match bible references to assign the correct `book_id` and `chapter`.
- The matching logic uses explicit exclusion checks to prevent author names containing biblical terms (such as "John Gill" or "Matthew Henry") from being parsed as book matches ("John" or "Matthew").

### 2.2 Text Normalization & Correction
- Common typographic errors and misspellings in legacy commentaries (e.g., "Zephahiah" for Zephaniah or misplaced chapter titles in Korean Matthew Henry commentaries) are programmatically corrected during this phase.
- Headers (such as markdown style headers) are preserved at the beginning of the text to represent article titles.

### 2.3 Optimization
- The database is rebuilt from scratch, and a `VACUUM` command is executed to compress binary storage size and optimize indexing performance before packaging.

---

## 3) Core Reader Implementation

### 3.1 State and Navigation Management
- Navigation uses a centralized controller that tracks the user's active location.
- **Persistence**: Book ID and chapter indices are updated in local preferences upon page changes.
- **Database Boundary Clamping**: When the active Bible version is swapped, the controller validates the current position against the new database limits. If the book ID exceeds the maximum books, it resets to the first book; if the chapter exceeds the maximum chapters of the current book, it clamps to the maximum chapter limit.

### 3.2 Commentary Pane and Toggle Logic
- The reader layout features a split viewport showing the scripture text on top and commentary on the bottom.
- A boolean visibility controller governs the commentary pane's display.
- Users can close the pane or toggle it off via the toolbar. Toggling it back on immediately restores the last viewed commentary article for the active chapter.

### 3.3 Introduction Viewer Modal
- **Trigger Points**:
  - Tapping the Book icon in the active Commentary Pane header.
  - Tapping the Information icon on a commentary package entry inside the selection sheet.
- **List Presentation**: Displays a sheet showing available general prefaces (using info icons) and book-specific introductions (using book icons).
- **Styled Viewport**: A dedicated page parses and renders the introduction content. It interprets markdown-style headers (translating header symbols to scaled, bold primary-colored titles) and inline formatting tags (such as bold and italics tags) using appropriate text styling.

---

## 4) User Data Schema (`user_data.db`)

### 4.1 Tables
- **`bookmarks`**: Logs marked verses with references and creation timestamps.
- **`highlights`**: Stores verse keys paired with a color code.
- **`notes`**: Saves user-written notes associated with specific verses, with creation and update timestamps.
- **`history`**: Tracks recently opened locations. A clean-up routine runs during inserts to delete older entries and cap the total row count at 50.
- **`settings`**: Key-value table storing active translations, font preferences, line heights, and theme settings.

---

## 5) Selection and Exporting

### 5.1 Selection State Machine
- **None**: Neutral reading state. Tapping a verse selects it.
- **Single Selection**: One verse is active. Shows the action bar with functions for Copy, Share, Jump to Commentary, Bookmark, Highlight, and Add Note.
- **Multi-Selection**: Activated via long-press. Multiple verses can be selected. The action bar hides the "Jump to Commentary" button. Tapping selected verses toggles their state.

### 5.2 Export Formatting Contract
- Exported text must follow this layout:
  - Header: Book Name, Chapter, and Verse Range (e.g., John 3:16-18 or John 3:16,18,20).
  - A blank line separator.
  - Bulleted or bracketed verse lines containing the chapter, verse number, and the corresponding text.
- Before formatting, selected verse tuples are sorted in canonical biblical order.

---

## 6) Debounced Search Spec (LIKE queries)

- Search text inputs are trimmed of outer whitespace.
- Query execution starts after a debounce delay (e.g., 300 milliseconds) and cancels any outstanding in-flight queries.
- Input length limits:
  - Latin or other alphabetic scripts require a minimum of 2 characters.
  - CJK characters require a minimum of 1 character.
- Searches execute database-level `LIKE` queries with escaped search wildcards.
- Results are paginated by offset increments and sorted chronologically by book, chapter, and verse.

---

## 7) Theme & Local Typography

- **Contrast Verification**: Contrasts for scripture body text must meet standard accessibility requirements across light and dark modes.
- **Color Scheme**: Employs a warm, low-fatigue cream or paper canvas for light mode, and a deep charcoal or slate palette for dark mode.
- **Local Assets Only**: No external font loaders or remote network requests are allowed. Fonts must be loaded strictly from local directories.

---

## 8) Replication and QA Protocol

### 8.1 Automated Unit Tests
- **Database Copying**: Unit tests should copy pre-processed SQLite databases directly from the assets directory into a temporary test directory rather than trying to extract them from raw zip archives.
- **Commentary Extraction**: Tests must verify both normal chapter commentary retrieval and introduction/preface loading.
- **Persistence Testing**: Verify that position values are stored and clamped correctly when Mock SharedPreferences are updated with boundary-breaking indices.

### 8.2 Build & Compilation Checks
- Run static analysis to verify that the project builds without warnings, unused imports, or deprecated library references.
- Verify that runtime zip extraction logic extracts assets cleanly to the app's documents directory across target native platforms.
