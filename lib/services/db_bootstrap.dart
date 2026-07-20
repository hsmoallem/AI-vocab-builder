/// ─── Database Factory Bootstrap ─────────────────────────────────────
///
/// Picks the right sqflite backend per platform via a conditional import:
///   • mobile/desktop → default sqflite factory (no-op)
///   • web            → sqflite_common_ffi_web (SQLite in WASM + IndexedDB)
///
/// Call [configureDatabaseFactory] once in main() BEFORE any DB access.

export 'db_bootstrap_stub.dart'
    if (dart.library.html) 'db_bootstrap_web.dart';
