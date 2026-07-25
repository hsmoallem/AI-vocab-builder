/// ─── Settings Screen ─────────────────────────────────────────────────
///
/// User preferences:
/// 1. App UI language (English / German)
/// 2. Default translation target language (German default)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../config/app_strings.dart';
import '../services/auto_backup.dart';
import '../services/export_service.dart';
import '../services/database_service.dart';

import 'package:go_router/go_router.dart';
import '../providers/word_provider.dart';
import '../services/study_prefs.dart';
import '../widgets/searchable_dropdown.dart';
import 'user_guide_screen.dart';

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
                ButtonSegment(value: 'ar', label: Text('العربية')),
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
            child: SearchableDropdown<String>(
              value: locale.targetLang,
              labelText: '',
              hideUnderline: false,
              items: AppStrings.targetLanguages.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              itemAsString: (key) => AppStrings.targetLanguages[key] ?? key,
              onChanged: (v) {
                if (v != null) locale.setTargetLang(v);
              },
            ),
          ),

          // ── Automatic backup ────────────────────────────────
          const _Section(
            icon: Icons.cloud_upload_outlined,
            title: 'Automatic backup',
            subtitle: 'Back up to the cloud on a schedule (signed-in accounts)',
            child: _AutoBackupControl(),
          ),

          // ── New cards per session ───────────────────────────
          const _Section(
            icon: Icons.layers_outlined,
            title: 'Cards per session',
            subtitle: 'Max total cards in a study session (due + new). All = no limit',
            child: _NewCardsControl(),
          ),

          // ── Reset all progress ─────────────────────────────
          _Section(
            icon: Icons.restart_alt,
            title: 'Reset all study progress',
            subtitle: 'Clear SRS for all cards so you can study them fresh again',
            child: const _ResetAllButton(),
          ),

          // ── User guide ──────────────────────────────────────
          _Section(
            icon: Icons.help_outline,
            title: 'User guide',
            subtitle: 'Flashcards, spaced repetition, study modes, and more',
            last: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/guide'),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Open guide'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SegmentedButton control for the automatic-backup frequency, backed by
/// SharedPreferences via [AutoBackup].
class _AutoBackupControl extends StatefulWidget {
  const _AutoBackupControl();

  @override
  State<_AutoBackupControl> createState() => _AutoBackupControlState();
}

class _AutoBackupControlState extends State<_AutoBackupControl> {
  String _freq = AutoBackup.freqOff;

  @override
  void initState() {
    super.initState();
    AutoBackup.getFrequency().then((f) {
      if (mounted) setState(() => _freq = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: AutoBackup.freqOff, label: Text('Off')),
        ButtonSegment(value: AutoBackup.freqDaily, label: Text('Daily')),
        ButtonSegment(value: AutoBackup.freqWeekly, label: Text('Weekly')),
      ],
      selected: {_freq},
      showSelectedIcon: false,
      onSelectionChanged: (v) async {
        setState(() => _freq = v.first);
        await AutoBackup.setFrequency(v.first);
      },
    );
  }
}

/// Dropdown for how many NEW cards a session introduces (10/20/30/50/All),
/// backed by SharedPreferences via [StudyPrefs].
class _NewCardsControl extends StatefulWidget {
  const _NewCardsControl();

  @override
  State<_NewCardsControl> createState() => _NewCardsControlState();
}

class _NewCardsControlState extends State<_NewCardsControl> {
  static const List<int> _options = [10, 20, 30, 50, StudyPrefs.all];
  int? _value; // null = still loading from prefs

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await StudyPrefs.newCardsPerSession();
    if (mounted) setState(() => _value = _options.contains(n) ? n : 30);
  }

  String _label(int n) => n == StudyPrefs.all ? 'All' : '$n';

  @override
  Widget build(BuildContext context) {
    if (_value == null) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SearchableDropdown<int>(
      value: _value,
      labelText: '',
      hideUnderline: false,
      items: _options
          .map((n) => DropdownMenuItem(value: n, child: Text(_label(n))))
          .toList(),
      itemAsString: (n) => _label(n),
      onChanged: (v) async {
        if (v == null) return;
        setState(() => _value = v);
        await StudyPrefs.setNewCardsPerSession(v);
      },
    );
  }
}

/// Button that resets SRS for all cards.
class _ResetAllButton extends StatefulWidget {
  const _ResetAllButton();

  @override
  State<_ResetAllButton> createState() => _ResetAllButtonState();
}

class _ResetAllButtonState extends State<_ResetAllButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading
            ? null
            : () => _confirmReset(context),
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.restart_alt),
        label: Text(_loading ? 'Resetting...' : 'Reset All'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
          'This will clear the SRS schedule for ALL cards. '
          'All cards will appear as "new" in your next study session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final provider = context.read<WordProvider>();
      await provider.resetAllSrs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All study progress cleared. Cards are ready for study!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to clear progress: $msg'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
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
