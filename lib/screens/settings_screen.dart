/// ─── Settings Screen ─────────────────────────────────────────────────
///
/// User preferences:
/// 1. App UI language (English / German)
/// 2. Default translation target language (German default)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
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
            last: true,
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
        ],
      ),
    );
  }
}

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
