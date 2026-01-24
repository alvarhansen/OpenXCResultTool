# Web Harness TODO

## Quick Wins
- [x] Add `version` command to the web harness.
- [x] Add `get metadata` command to the web harness.
- [x] Keep `test-results summary` exposed and stable.
- [x] Add `test-results tests` command to the web harness.

## Low Effort
- [x] Add `test-results metrics` (optional testId) to the web harness.
- [x] Add `test-results insights` to the web harness.
- [x] Add `format description` to the web harness.
- [x] Add `graph` to the web harness.

## Medium Effort
- [x] Add `test-results test-details` (requires testId picker) to the web harness.
- [x] Add `test-results activities` (requires testId picker) to the web harness.
- [x] Add `get object` (id input + format options) to the web harness.
- [x] Add `compare` (two bundles + diff output) to the web harness.

## Higher Effort
- [x] Add `export diagnostics` (download zip) to the web harness.
- [x] Add `export attachments` (download zip) to the web harness.
- [x] Add `export metrics` (download zip) to the web harness.
- [x] Add `export object` (download zip) to the web harness.
- [ ] Add `merge` (multi-upload + output bundle/zip) to the web harness.
- [ ] Add `format description diff` (two bundles + diff view) to the web harness.
- [ ] Add attachment/log viewer UI (preview + filters) to the web harness.

## Code Review Tasklist
- [x] Fix zstd streaming use-after-free in `ZstdDecompressor`.
- [x] Guard merge output path overlaps with inputs.
- [x] Roll back merge transaction on failure instead of deferred commit.
- [x] Surface sqlite step errors in `SQLiteDatabase.query`.
- [x] Surface sqlite step errors in merge table scans.
- [x] Add size bounds checks for zstd known-size decompression.
- [ ] Reduce CLI JSON output formatting duplication.
- [ ] Avoid `Data` -> `[UInt8]` copy in `XCResultRawParser`.
- [ ] Add WASI registry cleanup API for repeated browser runs.
- [ ] Deduplicate WASM SQLite open logic with the core module.
