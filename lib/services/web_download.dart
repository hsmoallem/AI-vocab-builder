/// ─── File download (web) ────────────────────────────────────────────
///
/// On web, triggers a browser download of text content. On every other
/// platform this stub is selected and throws — callers must guard with
/// kIsWeb and use the native share sheet instead.

export 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';
