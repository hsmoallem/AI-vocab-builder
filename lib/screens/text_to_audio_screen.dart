import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_strings.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/web_top_bar.dart';

class TextToAudioScreen extends StatefulWidget {
  const TextToAudioScreen({super.key});

  @override
  State<TextToAudioScreen> createState() => _TextToAudioScreenState();
}

class _TextToAudioScreenState extends State<TextToAudioScreen> {
  final TextEditingController _textController = TextEditingController();
  final FlutterTts _tts = FlutterTts();
  
  LanguageIdentifier? _languageIdentifier;
  String _selectedLang = 'en'; // Default
  bool _isDetecting = false;
  bool _isPlaying = false;
  bool _isSaving = false;

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

    setState(() => _isPlaying = true);
    try {
      await _tts.setLanguage(_selectedLang);
      await _tts.speak(text);
      
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _saveAudioAndText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (kIsWeb) {
      // share_plus on web can share text, but we cannot generate an audio file via flutter_tts natively on web.
      await Share.share(text, subject: 'Text-to-Audio Export');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dir = await getTemporaryDirectory();
      
      // Save Text
      final txtPath = '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.txt';
      final txtFile = File(txtPath);
      await txtFile.writeAsString(text);

      // Save Audio
      // flutter_tts synthesizeToFile generates a .wav or .mp3 file
      final audioFileName = 'export_${DateTime.now().millisecondsSinceEpoch}.mp3';
      
      await _tts.setLanguage(_selectedLang);
      
      // synthesizeToFile returns 1 on success
      final result = await _tts.synthesizeToFile(text, audioFileName);
      
      if (result == 1) {
        // The file is typically saved in the app's standard directory.
        // On Android, it's usually getExternalStorageDirectory() or similar.
        // We need to locate the file depending on the platform.
        // Actually flutter_tts synthesizeToFile saves to getApplicationDocumentsDirectory on iOS,
        // and external storage on Android. This is highly unreliable for sharing.
        // We can just share the text if it fails or if the file cannot be found.
        
        // Wait for TTS to finish saving
        await Future.delayed(const Duration(seconds: 2));
        
        final PlatformFilePaths = <String>[];
        if (Platform.isIOS) {
           final appDir = await getApplicationDocumentsDirectory();
           PlatformFilePaths.add('${appDir.path}/$audioFileName');
        } else if (Platform.isAndroid) {
           final appDir = await getExternalStorageDirectory();
           if (appDir != null) PlatformFilePaths.add('${appDir.path}/$audioFileName');
        }
        
        final filesToShare = <XFile>[XFile(txtPath)];
        for (final p in PlatformFilePaths) {
          if (File(p).existsSync()) {
            filesToShare.add(XFile(p));
            break;
          }
        }

        await Share.shareXFiles(filesToShare, text: 'Here is your text and audio export.');
      } else {
        // Fallback to sharing only text if audio generation failed
        await Share.shareXFiles([XFile(txtPath)], text: 'Here is your text export (Audio generation failed).');
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text-to-Audio Converter'),
        actions: kIsWeb ? WebTopBar.buildActions(context) : null,
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
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Type or paste text here to convert to audio...',
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
                    onPressed: _isPlaying ? () {
                      _tts.stop();
                      setState(() => _isPlaying = false);
                    } : _playAudio,
                    icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                    label: Text(_isPlaying ? 'Stop' : 'Play Audio'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _isPlaying ? cs.error : cs.primary,
                      foregroundColor: _isPlaying ? cs.onError : cs.onPrimary,
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
