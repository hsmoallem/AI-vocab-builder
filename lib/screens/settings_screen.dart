/// ─── Settings Screen ─────────────────────────────────────────────────
///
/// User preferences:
/// 1. App UI language (English / German)
/// 2. Default translation target language (German default)
/// 3. Export all words to a JSON file

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../providers/locale_provider.dart';
import '../providers/word_provider.dart';
import '../config/app_strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final locale = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        children: [
          // ── App Language ────────────────────────────────────
          _Section(
            icon: Icons.language,
            title: s.appLanguage,
            subtitle: s.appLanguageDesc,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'de', label: Text('Deutsch')),
              ],
              selected: {locale.locale},
              onSelectionChanged: (v) => locale.setLocale(v.first),
            ),
          ),

          // ── Translate Target Language ───────────────────────
          _Section(
            icon: Icons.translate,
            title: s.translateLanguage,
            subtitle: s.translateLanguageDesc,
            child: DropdownButtonFormField<String>(
              value: locale.targetLang,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: AppStrings.targetLanguages.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) locale.setTargetLang(v);
              },
            ),
          ),

          // ── Export Words ────────────────────────────────────
          _Section(
            icon: Icons.file_download,
            title: s.exportWords,
            subtitle: s.exportWordsDesc,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _exportWords(context),
                icon: const Icon(Icons.file_download),
                label: Text(s.exportWords),
              ),
            ),
            last: true,
          ),
        ],
      ),
    );
  }

  Future<void> _exportWords(BuildContext context) async {
    final s = AppStrings.of(context);
    final words = context.read<WordProvider>().words;

    try {
      final json = jsonEncode(
        words.map((w) => w.toMap()).toList(),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ai_vocab_builder_export.json');
      await file.writeAsString(json);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.exportSuccess(words.length)}\n${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.exportFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Reusable section wrapper with icon, title, subtitle, and a child widget.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool last;

  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
          if (!last) const Divider(height: 30),
        ],
      ),
    );
  }
}
