import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/word_provider.dart';
import 'web_daily_phrases_screen.dart';
import 'web_word_list_screen.dart';
import '../settings_screen.dart'; 
import '../text_to_audio_screen.dart';
import '../../config/app_strings.dart';
import 'web_reader_screen.dart';
import '../ai_quiz_screen.dart';
import '../../widgets/add_word_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class WebDashboardLayout extends StatefulWidget {
  const WebDashboardLayout({super.key});

  @override
  State<WebDashboardLayout> createState() => _WebDashboardLayoutState();
}

class _WebDashboardLayoutState extends State<WebDashboardLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    WebReaderScreen(),
    WebWordListScreen(),
    WebDailyPhrasesScreen(),
    TextToAudioScreen(),
    AiQuizScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              extended: true,
              minExtendedWidth: 260,
              backgroundColor: Colors.transparent,
              indicatorColor: theme.colorScheme.primary.withOpacity(0.15),
              selectedIconTheme: IconThemeData(color: theme.colorScheme.primary, size: 28),
              unselectedIconTheme: IconThemeData(color: theme.colorScheme.onSurface.withOpacity(0.6), size: 24),
              selectedLabelTextStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.language,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Text(
                          'Vocab Builder',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Beta',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Streak Flame (hidden for anonymous users)
                    if (!context.watch<AuthProvider>().isAnonymous) ...[
                      const Icon(Icons.local_fire_department, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '${context.watch<WordProvider>().streak.current}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  selectedIcon: const Icon(Icons.picture_as_pdf),
                  label: Text(s.tabReader),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.list_alt_outlined),
                  selectedIcon: const Icon(Icons.list_alt),
                  label: Text(s.tabMyWords),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  selectedIcon: const Icon(Icons.auto_awesome),
                  label: Text(s.tabDaily),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.record_voice_over_outlined),
                  selectedIcon: Icon(Icons.record_voice_over),
                  label: Text('Text-to-Audio'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: Text('AI Quizzes & Stories'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(s.settings),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'developed by Houssam moallem',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        InkWell(
                          onTap: () => launchUrl(Uri.parse('https://houssammoallem.com/')),
                          child: Text(
                            'houssammoallem.com',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              decoration: TextDecoration.underline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'feel free to share your feedback to\nmoallem.houssam@gmail.com',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddWordDialog(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Word'),
      ),
    );
  }
}
