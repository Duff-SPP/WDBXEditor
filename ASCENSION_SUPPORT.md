# Ascension custom DBC support (WotLK 3.3.5a)

This branch adds an **opt-in-by-missing-definition raw WDBC fallback** to WDBXEditor without changing the existing retail DBC/DB2 definitions or their normal read/write paths.

## Open an Ascension DBC

1. Open a **copy** of an extracted `.dbc` file (not an MPQ or listfile).
2. Select **WotLK 3.3.5 (12340)**.
3. If there is no existing named definition, compatible `WDBC` files open using `_Row`, `Field_000`, `Field_001` etc., and up to three `TailByte_*` columns.

The virtual `_Row` ID is not stored on disk; repeated first-field values are allowed. The raw columns are **opaque integers/bytes** and do not imply signed IDs, floats, string offsets, arrays, or known field semantics. Text is not decoded. The original string block is kept byte-for-byte when saving, rather than being reconstructed from guessed offsets.

### Safety constraints

Raw mode requires a standard `WDBC` signature, a nonzero record size, a file size matching `20 + recordCount*recordSize + stringBlockSize`, and a record width <= 65,536 bytes. Invalid files are rejected. Header `FieldCount` is preserved, but **not assumed** to equal `RecordSize / 4`, because custom tables may violate that assumption. An existing XML definition takes precedence and uses upstream behavior.

**This is not a verified schema pack**. Listfiles enumerate filenames but do not supply layouts. For the full Ascension-specific editor, we still need original extracted DBC binary samples to define field names/types/offsets and to test save-and-reopen against those files. Do not edit live game assets without backups.

### Build

The project targets **.NET Framework 4.6.1** and builds as a Windows desktop application. A dedicated workflow is in `.github/workflows/ascension-windows.yml` (branch push or manual dispatch); it produces a downloadable Windows artifact. On Windows with Visual Studio/MSBuild, build `WDBXEditor.sln` in Release after NuGet restore.

### Manual round-trip verification

- Open a copied unknown WDBC and confirm `_Row` is virtual and the raw values appear.
- Save without edits, then use `fc /b original.dbc saved.dbc` to check byte equality.
- Edit one known-safe integer in another copy, save/reopen, and compare all bytes; only the intended 4 bytes should differ.
- Verify a known WotLK DBC still opens/saves using its original named definition.
- Reject unsupported files rather than trying to interpret them as raw WDBC.

No release EXE or Ascension corpus-specific tests are claimed until CI and on-disk round-trips have passed.
