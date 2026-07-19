/// ─── Export Service ─────────────────────────────────────────────────
///
/// Builds the word list as CSV (opens in Excel/Sheets), plain text, or TSV
/// (pastes straight into spreadsheet cells), and shares the file via a native
/// Android share sheet (same MethodChannel approach as TTS / file picker).
///
/// Words are always ordered NEWEST-FIRST (most recently added on top).

import 'package:flutter/services.dart';
import '../models/word.dart';

class ExportService {
  static const _channel = MethodChannel('com.vocabreader/share');

  /// Newest added first; ties broken by id (higher id = newer).
  static List<Word> _newestFirst(List<Word> words) {
    final list = [...words];
    list.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : (b.id ?? 0).compareTo(a.id ?? 0);
    });
    return list;
  }

  static const _headers =
      'Word,Translation,Example (source),Example (target),From,To,Note,Grammar tip,Added';

  static String _csv(String s) => '"${s.replaceAll('"', '""')}"';

  static String toCsv(List<Word> words) {
    final b = StringBuffer()..writeln(_headers);
    for (final w in _newestFirst(words)) {
      b.writeln([
        w.word,
        w.translation,
        w.exampleSource,
        w.exampleTarget,
        w.sourceLang,
        w.targetLang,
        w.note ?? '',
        w.grammarTip ?? '',
        w.createdAt.toIso8601String(),
      ].map(_csv).join(','));
    }
    return b.toString();
  }

  /// Tab-separated — paste directly into Excel/Sheets cells.
  static String toTsv(List<Word> words) {
    String cell(String s) => s.replaceAll('\t', ' ').replaceAll('\n', ' / ');
    final b = StringBuffer()..writeln(_headers.replaceAll(',', '\t'));
    for (final w in _newestFirst(words)) {
      b.writeln([
        w.word,
        w.translation,
        w.exampleSource,
        w.exampleTarget,
        w.sourceLang,
        w.targetLang,
        w.note ?? '',
        w.grammarTip ?? '',
        w.createdAt.toIso8601String(),
      ].map(cell).join('\t'));
    }
    return b.toString();
  }

  static String toText(List<Word> words) {
    final b = StringBuffer();
    for (final w in _newestFirst(words)) {
      b.writeln('${w.word} — ${w.translation}  [${w.sourceLang}→${w.targetLang}]');
      if (w.exampleSource.isNotEmpty) {
        b.writeln('  ${w.exampleSource.replaceAll('\n', '\n  ')}');
      }
      if (w.exampleTarget.isNotEmpty) {
        b.writeln('  ${w.exampleTarget.replaceAll('\n', '\n  ')}');
      }
      if ((w.grammarTip ?? '').isNotEmpty) b.writeln('  Grammar: ${w.grammarTip}');
      if ((w.note ?? '').isNotEmpty) b.writeln('  Note: ${w.note}');
      b.writeln();
    }
    return b.toString();
  }

  /// Write [content] to a cache file and open the Android share sheet.
  static Future<void> shareFile({
    required String content,
    required String filename,
    required String mime,
  }) async {
    await _channel.invokeMethod('shareFile', {
      'content': content,
      'filename': filename,
      'mime': mime,
    });
  }
}
