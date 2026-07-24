import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

// Colors based on Tailwind Slate palette
const _slate900 = Color(0xFF0F172A);
const _slate800 = Color(0xFF1E293B);
const _slate700 = Color(0xFF334155);
const _slate500 = Color(0xFF64748B);
const _slate400 = Color(0xFF94A3B8);
const _slate300 = Color(0xFFCBD5E1);

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
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 256,
            height: double.infinity,
            decoration: BoxDecoration(
              color: _slate900,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header / Logo
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _slate800)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: FaIcon(FontAwesomeIcons.brain, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Vocab Builder',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'BETA',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Navigation Links
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SidebarItem(
                          icon: FontAwesomeIcons.filePdf,
                          label: s.tabReader,
                          isSelected: _selectedIndex == 0,
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                        const SizedBox(height: 4),
                        _SidebarItem(
                          icon: FontAwesomeIcons.list,
                          label: s.tabMyWords,
                          isSelected: _selectedIndex == 1,
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                        const SizedBox(height: 4),
                        _SidebarItem(
                          icon: FontAwesomeIcons.wandMagicSparkles,
                          label: s.tabDaily,
                          isSelected: _selectedIndex == 2,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                        const SizedBox(height: 4),
                        _SidebarItem(
                          icon: FontAwesomeIcons.volumeHigh,
                          label: 'Text-to-Audio',
                          isSelected: _selectedIndex == 3,
                          onTap: () => setState(() => _selectedIndex = 3),
                        ),
                        const SizedBox(height: 4),
                        _SidebarItem(
                          icon: FontAwesomeIcons.bookOpenReader,
                          label: 'AI Quizzes',
                          isSelected: _selectedIndex == 4,
                          onTap: () => setState(() => _selectedIndex = 4),
                        ),
                        
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.only(left: 14, bottom: 8),
                          child: Text(
                            'ACCOUNT',
                            style: TextStyle(
                              color: _slate500,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        _SidebarItem(
                          icon: FontAwesomeIcons.gear,
                          label: s.settings,
                          isSelected: _selectedIndex == 5,
                          onTap: () => setState(() => _selectedIndex = 5),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _slate800)),
                  ),
                  child: Column(
                    children: [
                      if (!context.watch<AuthProvider>().isAnonymous)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _slate800.withOpacity(0.8),
                            border: Border.all(color: _slate700.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: FaIcon(FontAwesomeIcons.fireFlameCurved, color: Colors.amber, size: 14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${context.watch<WordProvider>().streak.current} Day Streak',
                                style: const TextStyle(
                                  color: _slate300,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'developed by Houssam moallem',
                        style: TextStyle(
                          color: _slate500,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => launchUrl(Uri.parse('https://houssammoallem.com/')),
                        child: const Text(
                          'houssammoallem.com',
                          style: TextStyle(
                            color: _slate400,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: _slate400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

class _SidebarItem extends StatefulWidget {
  final dynamic icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected;
    final bool showHover = _isHovering && !active;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active 
                ? null 
                : (showHover ? _slate800 : Colors.transparent),
            gradient: active 
                ? const LinearGradient(
                    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Center(
                  child: FaIcon(
                    widget.icon,
                    size: 16,
                    color: active || showHover ? Colors.white : _slate400,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: active || showHover ? Colors.white : _slate400,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
