import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_strings.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/web_top_bar.dart';
import '../services/tts_service.dart';

class TextToAudioScreen extends StatefulWidget {
  const TextToAudioScreen({super.key});

  @override
  State<TextToAudioScreen> createState() => _TextToAudioScreenState();
}

class _TextToAudioScreenState extends State<TextToAudioScreen> {
  final TextEditingController _textController = TextEditingController();
  final TtsService _tts = TtsService();
  
  LanguageIdentifier? _languageIdentifier;
  String _selectedLang = 'en'; // Default
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _languageIdentifier?.close();
    _tts.stop();
    super.dispose();
  }

  Future<void> _detectLanguage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _languageIdentifier == null) return;

    setState(() => _isDetecting = true);
    try {
      final language = await _languageIdentifier!.identifyLanguage(text);
      if (language != 'und' && AppStrings.targetLanguages.containsKey(language)) {
        setState(() {
          _selectedLang = language;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Language auto-detected: ${AppStrings.targetLanguages[language]}')),
          );
        }
      } else if (language != 'und') {
        // We have a detected language but it's not in our list
        // Try to map it if needed, or ignore
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auto-detected language is not fully supported for playback')),
          );
        }
      }
    } catch (e) {
      debugPrint('Language detection error: $e');
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<void> _playAudio() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    try {
      String langCode = _selectedLang;
      if (langCode == 'ar') langCode = 'ar-SA';
      else if (langCode == 'en') langCode = 'en-US';
      else if (langCode == 'zh') langCode = 'zh-CN';
      else if (langCode == 'ja') langCode = 'ja-JP';
      else if (langCode == 'ru') langCode = 'ru-RU';
      
      await _tts.speak(text, language: langCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text-to-Audio Converter'),
        actions: (kIsWeb && MediaQuery.of(context).size.width > 800) ? WebTopBar.buildActions(context) : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SearchableDropdown<String>(
                    value: _selectedLang,
                    labelText: 'Language',
                    items: AppStrings.targetLanguages.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    itemAsString: (key) => AppStrings.targetLanguages[key] ?? key,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLang = val);
                    },
                  ),
                ),
                // Auto-detect button removed per user request
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _textController,
                textDirection: _selectedLang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Type or paste text here to convert to audio...',
                  hintTextDirection: _selectedLang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (val) {
                  // Optional: we could auto-detect on typing pause
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _playAudio,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play Audio'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _tts.stop(),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Note: Audio file generation is not supported on the Web version. You can only export the text.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              )
          ],
        ),
      ),
    );
  }
}
