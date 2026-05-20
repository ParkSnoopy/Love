# Bible App Implementation Plan (Flutter + Drift, Offline, Strict Validation)

> For future execution after context compaction.
> Project root: current Flutter repo.
> Data source: `assets/data.zip` (already unpacked under `assets/data/` for analysis).
> Tone constraints already decided in session. This file is execution spec.

## 0) Locked Product Decisions (from grill)

1. Platform: Flutter first.
2. Scope: reader-first + study-core.
3. Data packaging: ship `assets/data.zip`; user selects version/commentary; unzip selected packs on demand.
4. Data integrity: strict fail import (any unresolved required mapping -> fail).
5. Commentary: user picks commentary pack per selected Bible version.
6. Search: no FTS; SQL `LIKE`; page size 100; infinite scroll by offset when bottom reached.
7. Storage policy: keep `assets/data.zip`; keep all extracted sets.
8. Navigation: book/chapter picker + chapter swipe + verse tap actions.
9. Study v1: bookmarks, 3-color highlights, notes, recent history (50).
10. User data in separate DB (`user_data.db`), source Bible/comment DB read-only.
11. Import UX: background isolate + progress phases + retry.
12. Failure UX split:
   - debug: crash with verbose error
   - release: simple error popup
13. State management: Riverpod.
14. DB layer: Drift (web-support path).
15. Web: import selected packs once into browser storage; clear-packs option.
16. License gate: skip in v1 (no blocking).
17. Module split:
   - features/library
   - features/reader
   - features/study
   - features/search
   - data/drift
   - data/import
18. Verse selection UX:
   - tap = single select
   - long-press = multi-select mode
   - actions: Copy / Share / Jump Comment (jump disabled for multi)
19. Export format:
   - header: `Book Chapter:Verse-Range`
   - blank line
   - body lines: `[Chapter:Verse] verse_content`
20. Comment jump fallback: open commentary pane with “No commentary installed/mapped…” + Manage packs button.
21. Version switch: keep same ref; clamp if verse/chapter missing.
22. Theme:
   - mode: light/dark/system (default system)
   - palette reference: `https://getdesign.md/design-md/claude/preview`
   - controls: global font-type + font-size + line-height
   - fonts: strict local only from `assets/fonts/*`
23. Ship gate fixed (must all pass before v1 release).
24. Commentary reference parser grammar: full set (single, ranges, cross-chapter, comma list, shorthand, aliases).

---

## 1) Current Repo Baseline

Observed:
- Flutter scaffold app only (`lib/main.dart` starter).
- Assets exist:
  - `assets/data.zip`
  - unpacked DBs under `assets/data/`
  - fonts under `assets/fonts/`
- `pubspec.yaml` minimal dependencies currently.

Implication: build from near-zero app layer. Keep architecture clean now.

---

## 2) Target Architecture (high-level)

### 2.1 Runtime data model

Three storage zones:
1. Bundled assets (read-only in package):
   - `assets/data.zip`
   - font files
2. Imported content packs (app sandbox):
   - extracted Bible DB(s)
   - extracted commentary DB(s)
   - generated mapping/index DB per pack pair
3. User state DB (`user_data.db`):
   - bookmarks
   - highlights
   - notes
   - recent history
   - settings (theme mode, font type, font size, line height, active pack IDs)

### 2.2 Domain layers

- `data/import`: zip extraction, schema validation, parser + commentary mapping build.
- `data/drift`: DB connections, DAOs, migrations.
- `features/library`: pack selection/install/activation.
- `features/reader`: chapter display, verse selection, commentary jump.
- `features/search`: LIKE search + offset pagination.
- `features/study`: bookmark/highlight/note/history.
- `app/theme`: Claude-inspired token mapping + local font switching.

### 2.3 Strict validation principle

Pack activation allowed only if all required checks pass:
- required tables present
- required columns present
- no duplicate PK in verse key space
- commentary reference parsing succeeds
- unresolved verse refs count == 0

If failure:
- debug build: throw with verbose diagnostic
- release build: concise popup
- previous active pack remains active

---

## 3) Proposed File/Folder Blueprint

Create under `lib/`:

```
lib/
  app/
    app.dart
    router.dart
    theme/
      app_theme.dart
      claude_palette.dart
      typography.dart
      theme_controller.dart
  core/
    constants/
      app_constants.dart
      asset_paths.dart
    errors/
      app_exception.dart
      import_exception.dart
    logging/
      logger.dart
    utils/
      ref_format.dart
      bible_ref_parser.dart
      verse_export_formatter.dart
  data/
    drift/
      content/
        content_db.dart
        content_db_web.dart
        content_db_native.dart
        tables/
          content_pack_tables.dart
          commentary_map_tables.dart
        dao/
          bible_read_dao.dart
          commentary_read_dao.dart
          search_dao.dart
      user/
        user_db.dart
        tables/
          bookmarks_table.dart
          highlights_table.dart
          notes_table.dart
          history_table.dart
          settings_table.dart
        dao/
          study_dao.dart
          settings_dao.dart
      converters/
        enum_converters.dart
      migrations/
        user_migrations.dart
    import/
      import_orchestrator.dart
      zip_extractor.dart
      schema_validator.dart
      commentary_mapper.dart
      manifest_loader.dart
      import_progress.dart
      import_report.dart
      isolate_entrypoint.dart
  features/
    library/
      data/
      domain/
        models/
          bible_pack.dart
          commentary_pack.dart
          install_state.dart
      presentation/
        pages/library_page.dart
        widgets/pack_selector.dart
        widgets/install_progress_card.dart
        widgets/pack_manage_sheet.dart
      providers/library_providers.dart
    reader/
      domain/models/
        verse_view_model.dart
        selection_state.dart
      presentation/
        pages/reader_page.dart
        widgets/chapter_swiper.dart
        widgets/verse_list.dart
        widgets/verse_tile.dart
        widgets/selection_action_bar.dart
        widgets/book_chapter_picker.dart
        widgets/commentary_pane.dart
      providers/reader_providers.dart
    search/
      domain/models/search_result.dart
      presentation/pages/search_page.dart
      presentation/widgets/search_result_list.dart
      providers/search_providers.dart
    study/
      presentation/widgets/note_editor_sheet.dart
      presentation/widgets/highlight_palette_sheet.dart
      providers/study_providers.dart
  bootstrap.dart
  main.dart
```

Add tests:

```
test/
  unit/
    core/bible_ref_parser_test.dart
    core/verse_export_formatter_test.dart
    data/import/schema_validator_test.dart
    data/import/commentary_mapper_test.dart
    data/search/like_pagination_test.dart
    data/study/study_dao_test.dart
  widget/
    library/install_flow_test.dart
    reader/selection_action_bar_test.dart
    reader/comment_jump_test.dart
    search/infinite_scroll_test.dart
  integration/
    app_smoke_test.dart
```

---

## 4) Dependencies to add (pubspec)

Core:
- `flutter_riverpod`
- `riverpod_annotation` (optional if using generator)
- `go_router` (optional but recommended)
- `drift`
- `drift_flutter` (or drift + platform-specific executors)
- `sqlite3`
- `sqlite3_flutter_libs`
- `path`
- `path_provider`
- `archive` (zip extract)
- `collection`
- `share_plus`
- `package_info_plus` (optional)
- `equatable` (optional)

Dev:
- `build_runner`
- `drift_dev`
- `riverpod_generator` (if using annotations)
- `flutter_lints`
- `mocktail`

Assets/fonts config in `pubspec.yaml`:
- include `assets/data.zip`
- include `assets/data/` only if needed for debug fixtures (optional)
- register font families:
  - Sans: `assets/fonts/NotoSansKR.ttf`
  - Serif: `assets/fonts/NotoSerifKR.ttf`
  - Mono: `assets/fonts/NanumGothicCoding.ttf`

---

## 5) Data Contract Specs

### 5.1 Bible DB expected schema (validated)

Tables:
- `books(book_id, osis, name_en, name_native, testament, chapter_count)`
- `verses(book_id, chapter, verse, text)`
- `version(slug, label)`

Required constraints (enforced by validator):
- non-null keys for verse tuple
- no duplicate `(book_id, chapter, verse)`
- verse text non-empty after trim

### 5.2 Commentary DB observed schema family

Typical tables:
- `articles(article_id, title, text)`
- `indexing(book_id, osis, name_en, name_native, testament, chapter_count)`
- `comment(slug, label)`

Because commentary rows often not pre-linked by verse tuple, mapping pipeline required.

### 5.3 Internal generated mapping table (app-owned)

Create app-managed table (content DB side or separate mapping DB):
- `commentary_verse_map`
  - `commentary_pack_id TEXT`
  - `article_id INTEGER`
  - `book_id INTEGER`
  - `chapter INTEGER`
  - `verse_start INTEGER`
  - `verse_end INTEGER`
  - `source_ref_text TEXT`
  - PK composite on (`commentary_pack_id`,`article_id`,`book_id`,`chapter`,`verse_start`,`verse_end`)

Use this for jump + commentary fetch by verse.

---

## 6) Reference Parser Spec (strict)

Parser inputs from commentary `title` and if needed `text` lead segment.

Must support:
1. Single ref: `John 3:16`
2. Same chapter range: `John 3:16-18`
3. Cross chapter range: `John 3:16-4:2`
4. Comma list same chapter: `John 3:16,18,20`
5. Context shorthand: `3:16-18` (book inferred from prior token/context)
6. Book aliases:
   - `osis`
   - `name_en`
   - `name_native`
   - curated alias table (e.g., `Gen`, `Ge`, localized abbreviations)

Strict rules:
- every parsed reference must map to existing Bible verse key.
- if any reference token parsed-but-unmapped => import fail.
- if commentary article expected to have reference but parser cannot extract deterministically => import fail.

Ambiguity policy:
- do not guess book if missing and no context.
- fail fast with diagnostics containing article id + offending snippet.

---

## 7) Search Spec (LIKE, no FTS)

Query behavior:
- trim input.
- min length:
  - CJK: >=1
  - other scripts: >=2
- SQL:
  - `WHERE text LIKE ? ESCAPE '\\'`
  - bind `%keyword%` with escaped wildcards.
- ordered by canonical reference `(book_id, chapter, verse)`.
- page size fixed 100.
- offset increments by 100 on scroll bottom.
- stop when fetched < 100.

Performance mitigations:
- debounce input (300ms).
- cancel stale in-flight query on new input.
- optional lightweight prefix cache in-memory for recent queries.

---

## 8) Reader + Selection + Export Spec

### 8.1 Selection state machine

States:
- `none`
- `single(verseKey)`
- `multi(Set<verseKey>)`

Transitions:
- tap in `none` -> `single`
- long-press in any -> `multi` with current verse included
- tap in `multi` toggles membership
- clear action -> `none`

### 8.2 Action bar behavior

Single mode:
- Copy
- Share
- Jump Comment
- Bookmark
- Highlight
- Add Note

Multi mode:
- Copy
- Share
- Bookmark (batch optional)
- Highlight (batch optional)
- Jump Comment disabled

### 8.3 Export formatting exact

Header line:
`{BookName} {Chapter}:{VerseRange}`

Blank line

Body lines:
`[{Chapter}:{Verse}] {VerseText}`

Range derivation:
- if all selected within same chapter contiguous, range `start-end`
- if disjoint, show compact comma/range expression (e.g., `3:16-18,20`)
- for cross chapter selection, header uses first ref to last ref: `3:16-4:2`

Sort always by canonical ref before export.

### 8.4 Jump commentary

For single selected verse:
- query `commentary_verse_map` by active commentary pack and verse key/range inclusion.
- if found -> open commentary pane at first best match; allow next/prev article nav.
- if none -> open pane with empty-state + `Manage commentary packs` button.

---

## 9) Study Data Spec (`user_data.db`)

Tables:
1. `bookmarks`
   - id, created_at, bible_pack_id, book_id, chapter, verse
2. `highlights`
   - id, color_code (3 options), created_at, bible_pack_id, book_id, chapter, verse
3. `notes`
   - id, created_at, updated_at, bible_pack_id, book_id, chapter, verse, content
4. `history`
   - id, opened_at, bible_pack_id, book_id, chapter, verse
   - retain max 50 (enforce via trigger or cleanup query)
5. `settings`
   - key/value table for:
     - active_bible_pack_id
     - active_commentary_pack_id
     - theme_mode (system/light/dark)
     - font_type (sans/serif/mono)
     - font_size
     - line_height

Indexes:
- composite indexes on reference tuples for fast lookup.

---

## 10) Theme Spec (Claude-inspired, local fonts only)

Reference palette from provided link (not remote runtime dependency).

Token mapping example:
- light background: warm canvas
- dark background: dark navy-like
- accent: coral
- support accents: muted teal/amber where needed

Rules:
- no runtime web font fetch.
- font families only local assets.
- global font switch applies app-wide text theme.
- separate sliders for font size + line height.
- default mode = system.

Accessibility checks:
- ensure readable contrast in both themes for scripture body text.
- minimum font size clamp.

---

## 11) Import Pipeline Detailed

Phases (progress UI should show each):
1. `Discover`: load `manifest.json`, list available packs.
2. `Extract`: unzip selected Bible/commentary DB files to app data directory.
3. `Validate Bible`: schema + key uniqueness + non-empty text checks.
4. `Validate Commentary`: schema checks.
5. `Build Alias Map`: from Bible books + commentary indexing + known alias table.
6. `Parse References`: extract references from commentary rows.
7. `Resolve References`: map each parsed ref to verse keys.
8. `Build Mapping Table`: persist `commentary_verse_map`.
9. `Finalize`: write install metadata + mark pack active.

Failure handling:
- produce structured `ImportReport`:
  - phase
  - fatal message
  - article id / row id if relevant
  - snippet
  - counters (parsed, mapped, unresolved)
- debug: throw `ImportException.verbose(report)`
- release: popup generic failure + short code (e.g., `IMPORT_REF_UNRESOLVED`)

Concurrency:
- run heavy parse/mapping in isolate.
- progress updates via stream/provider.

---

## 12) Web-specific Plan (Drift web)

Storage target:
- Drift web backend persisted in browser storage (IndexedDB/opfs depending adapter).

Web install flow:
1. user chooses pack
2. app extracts selected files (from bundled zip or fetched asset)
3. import/validation pipeline runs
4. generated DB/mapping persisted locally
5. settings retains active packs

Management:
- settings page action: `Clear installed packs` (confirm dialog)

Caveats:
- browser storage quota errors must surface gracefully.
- for large commentary, show estimated size before install (optional stretch).

---

## 13) Milestone Plan (execution order)

### Milestone A: Foundation bootstrap
- Add dependencies.
- Configure assets/fonts in pubspec.
- Replace scaffold `main.dart` with app bootstrap + Riverpod scope.
- Add theme skeleton + settings persistence stubs.

Exit criteria:
- app boots on mobile + web.
- theme mode switch works with placeholder UI.

### Milestone B: Data infrastructure
- Create Drift user DB schema + DAOs.
- Create content DB access wrapper for external sqlite files.
- Implement manifest loader for pack list.

Exit criteria:
- can list Bible/comment packs from manifest in UI.

### Milestone C: Import pipeline strict
- zip extractor.
- schema validator.
- commentary ref parser + resolver.
- mapping table build.
- import report + progress stream + isolate.

Exit criteria:
- selected pack install completes for known-good sample.
- forced bad sample fails with expected diagnostics.

### Milestone D: Reader core
- book/chapter picker.
- verse list by active version.
- chapter swipe prev/next.
- version switch keep reference + clamp.

Exit criteria:
- stable chapter navigation and render.

### Milestone E: Selection + actions
- single/multi selection state machine.
- action bar.
- copy/share export formatter exact spec.
- jump commentary + empty state path.

Exit criteria:
- export output matches exact format.
- jump works when mapped.

### Milestone F: Search
- LIKE search DAO.
- min-length policy by script.
- pagination + infinite scroll.

Exit criteria:
- first 100 results then load-next works.

### Milestone G: Study features
- bookmark/highlight/note/history.
- history cap 50 enforcement.

Exit criteria:
- data persists across restart.

### Milestone H: Polishing + release gate
- release vs debug error split.
- manage packs screen.
- clear installed packs.
- full regression + ship checklist.

Exit criteria:
- all ship-gate items green.

---

## 14) QA/Testing Strategy

### 14.1 Unit tests (must-have)
- parser grammar coverage for all required forms.
- resolver mapping correctness.
- validator strict fail behavior.
- export formatter exact string snapshots.
- search pagination and offset logic.

### 14.2 Widget tests
- selection transitions tap/long-press.
- action bar state (single vs multi).
- commentary empty-state pane behavior.
- import progress UI phase transitions.

### 14.3 Integration tests
- end-to-end install selected Bible + commentary.
- navigate chapter, select verse, jump commentary.
- perform search + infinite scroll.
- add note/highlight/bookmark persists.

### 14.4 Manual smoke matrix
- Android debug
- Android release
- iOS debug/release (if env)
- Web Chrome
- Desktop optional

---

## 15) Build/Run/Test Commands (planned)

Initial:
- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs`

Run:
- `flutter run -d android`
- `flutter run -d chrome`

Test:
- `flutter test`
- targeted:
  - `flutter test test/unit/core/bible_ref_parser_test.dart`
  - `flutter test test/widget/reader/selection_action_bar_test.dart`

Release checks:
- `flutter build apk --release`
- `flutter build web --release`

---

## 16) Key Risks + Mitigations

1. Commentary reference heterogeneity
   - Risk: many malformed ref patterns.
   - Mitigation: staged parser with explicit diagnostics and fixture corpus from multiple commentary DBs.

2. LIKE search performance on large DB
   - Risk: slow query on low-end devices.
   - Mitigation: strict page cap 100, debounce, cancellable queries, optional prefilter by book/chapter in UI later.

3. Web storage quota
   - Risk: install failure due quota.
   - Mitigation: size estimate + clear-packs tool + actionable error.

4. Drift + external sqlite interop complexity
   - Risk: using read-only external DB alongside managed user DB.
   - Mitigation: isolate DB responsibilities clearly; keep content DB read-only connectors and user DB separate.

5. Debug/release behavior divergence
   - Risk: hidden issues in release.
   - Mitigation: run full import flow in release build during QA.

---

## 17) Ship Gate Checklist (must all be true)

- [ ] Bible/comment pack pick + unzip + strict validate passes for target fixtures.
- [ ] Reader nav/swipe/picker stable.
- [ ] Verse single/multi select stable.
- [ ] Export exact format matches spec.
- [ ] Commentary jump works; unresolved refs = 0 for installed pair.
- [ ] Search LIKE pagination (100/page + infinite scroll) works.
- [ ] Bookmarks/highlights/notes/history(50) persistent.
- [ ] Theme mode + global font type/size + line-height work.
- [ ] Debug build crashes verbose on strict-fail.
- [ ] Release build shows simple popup on strict-fail.

---

## 18) Suggested Implementation Sequence (tiny tasks, commit-friendly)

Phase 1 commits:
1. chore: add dependencies and asset/font config.
2. feat: bootstrap app + Riverpod + base routing.
3. feat: add theme tokens + settings persistence.

Phase 2 commits:
4. feat: add user_data drift schema + DAOs.
5. feat: add manifest loader and pack list UI.

Phase 3 commits:
6. feat: zip extraction service.
7. feat: bible schema validator.
8. feat: commentary schema validator.
9. feat: reference parser core grammar.
10. feat: resolver + mapping table builder.
11. feat: import orchestrator + progress stream.
12. feat: debug/release fail split behavior.

Phase 4 commits:
13. feat: reader page + book/chapter picker + swipe nav.
14. feat: verse selection state machine.
15. feat: selection action bar + copy/share formatter.
16. feat: commentary jump + empty state.

Phase 5 commits:
17. feat: LIKE search + pagination providers/UI.
18. feat: study features (bookmark/highlight/note/history).
19. feat: pack management screen + clear packs.

Phase 6 commits:
20. test: parser/validator/search/selection coverage.
21. test: integration smoke paths.
22. chore: release build QA and bug fixes.

---

## 19) Non-goals (v1)

- Licensing enforcement gate.
- Cloud sync/account.
- FTS index.
- Complex study analytics.
- Multi-pane comparison beyond initial design unless capacity remains.

---

## 20) Ready-to-execute summary

This plan intentionally over-specifies:
- architecture
- DB contracts
- parser grammar
- strict validation behavior
- UI state transitions
- milestone/commit sequence
- QA gates

After context compaction, execution can proceed directly from this file without re-grill.
