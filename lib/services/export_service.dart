/// ─── Export Service ─────────────────────────────────────────────────
///
/// Builds the word list as CSV (opens in Excel/Sheets), plain text, or TSV
/// (pastes straight into spreadsheet cells), and shares the file via a native
/// Android share sheet (same MethodChannel approach as TTS / file picker).
///
/// Words are always ordered NEWEST-FIRST (most recently added on top).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/word.dart';
import 'web_download.dart';
import 'analytics_service.dart';

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
      'Word,Translation,Part of speech,IPA,Article,Plural,Feminine,Infinitive,Verb type,Example (source),Example (target),From,To,Note,Grammar tip,Usage note,Added';

  static String _csv(Object? s) => '"${(s ?? '').toString().replaceAll('"', '""')}"';

  static String toCsv(List<Word> words) {
    final b = StringBuffer()..writeln(_headers);
    for (final w in _newestFirst(words)) {
      final gd = w.grammarData ?? <String, dynamic>{};
      b.writeln([
        w.word,
        w.translation,
        w.partOfSpeech ?? '',
        gd['ipa'] ?? '',
        gd['article'] ?? '',
        gd['plural'] ?? '',
        gd['feminine'] ?? '',
        gd['infinitive'] ?? '',
        gd['verb_type'] ?? '',
        w.exampleSource,
        w.exampleTarget,
        w.sourceLang,
        w.targetLang,
        w.note ?? '',
        w.grammarTip ?? '',
        w.usageNote ?? '',
        w.createdAt.toIso8601String(),
      ].map(_csv).join(','));
    }
    return b.toString();
  }

  static String _tsv(Object? s) =>
      (s ?? '').toString().replaceAll('\t', ' ').replaceAll('\n', ' ').replaceAll('\r', '');

  static String toTsv(List<Word> words) {
    final b = StringBuffer()
      ..writeln([
        'Word',
        'Translation',
        'Part of speech',
        'IPA',
        'Article',
        'Plural',
        'Feminine',
        'Infinitive',
        'Verb type',
        'Example (source)',
        'Example (target)',
        'From',
        'To',
        'Note',
        'Grammar tip',
        'Usage note',
        'Added'
      ].join('\t'));
    for (final w in _newestFirst(words)) {
      final gd = w.grammarData ?? <String, dynamic>{};
      b.writeln([
        w.word,
        w.translation,
        w.partOfSpeech ?? '',
        gd['ipa'] ?? '',
        gd['article'] ?? '',
        gd['plural'] ?? '',
        gd['feminine'] ?? '',
        gd['infinitive'] ?? '',
        gd['verb_type'] ?? '',
        w.exampleSource,
        w.exampleTarget,
        w.sourceLang,
        w.targetLang,
        w.note ?? '',
        w.grammarTip ?? '',
        w.usageNote ?? '',
        w.createdAt.toIso8601String(),
      ].map(_tsv).join('\t'));
    }
    return b.toString();
  }

  static String toText(List<Word> words) {
    final b = StringBuffer();
    for (final w in _newestFirst(words)) {
      final gd = w.grammarData ?? <String, dynamic>{};
      b.writeln('${w.word}  →  ${w.translation}');
      final pos = w.partOfSpeech ?? '';
      final ipaStr = gd['ipa']?.toString() ?? '';
      if (pos.isNotEmpty || ipaStr.isNotEmpty) {
        final ipaDisplay = ipaStr.isNotEmpty ? '[$ipaStr]' : '';
        b.writeln('  Grammar: ${'$pos $ipaDisplay'.trim()}');
      }
      final articleStr = gd['article']?.toString() ?? '';
      final pluralStr = gd['plural']?.toString() ?? '';
      final femStr = gd['feminine']?.toString() ?? '';
      if (articleStr.isNotEmpty || pluralStr.isNotEmpty || femStr.isNotEmpty) {
        final forms = <String>[];
        if (articleStr.isNotEmpty) forms.add('Art: $articleStr');
        if (pluralStr.isNotEmpty) forms.add('Pl: $pluralStr');
        if (femStr.isNotEmpty) forms.add('Fem: $femStr');
        b.writeln('  Forms: ${forms.join(', ')}');
      }
      if (w.exampleSource.isNotEmpty) {
        b.writeln('  ${w.exampleSource.replaceAll('\n', '\n  ')}');
      }
      if (w.exampleTarget.isNotEmpty) {
        b.writeln('  ${w.exampleTarget.replaceAll('\n', '\n  ')}');
      }
      if ((w.grammarTip ?? '').isNotEmpty) b.writeln('  Rule: ${w.grammarTip}');
      if ((w.usageNote ?? '').isNotEmpty) b.writeln('  Usage tip: ${w.usageNote}');
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
    AnalyticsService.trackEvent('export_file', {'filename': filename, 'format': mime});
    if (kIsWeb) {
      // Browser download instead of the native Android share sheet.
      downloadTextFile(content, filename, mime);
      return;
    }
    await _channel.invokeMethod('shareFile', {
      'content': content,
      'filename': filename,
      'mime': mime,
    });
  }
}
