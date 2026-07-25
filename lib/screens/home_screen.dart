import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import '../services/auto_backup.dart';
import 'mobile_dashboard_layout.dart';
import 'web/web_dashboard_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Silently sync cloud streak and run automatic cloud backup on launch across Web and Mobile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        final provider = context.read<WordProvider>();
        await provider.syncCloudStreak();
        final allWords = await provider.getAllWordsForBackup();
        if (mounted) {
          AutoBackup.maybeRun(allWords);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (kIsWeb && constraints.maxWidth > 800) {
          return const WebDashboardLayout();
        }
        return const MobileDashboardLayout();
      },
    );
  }
}

