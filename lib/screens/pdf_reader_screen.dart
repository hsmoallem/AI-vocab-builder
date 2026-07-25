import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync;
import '../widgets/add_word_dialog.dart';

class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  static const _channel = MethodChannel('com.vocabreader/picker');

  File? _pdfFile;
  String _pdfName = '';
  String _extractedText = '';
  bool _isLoading = false;
  bool _showText = false;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _showText = false;
    });

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('pickPdf');
      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      final path = result['path'] as String;
      final name = result['name'] as String? ?? 'document.pdf';
      final file = File(path);

      _extractTextInBackground(file);

      setState(() {
        _pdfFile = file;
        _pdfName = name;
        _isLoading = false;
      });
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
      setState(() {
        _error = 'Unable to open PDF: $msg';
        _isLoading = false;
      });
    }
  }

  void _extractTextInBackground(File file) {
    try {
      final bytes = file.readAsBytesSync();
      final document = sync.PdfDocument(inputBytes: bytes);
      final extractor = sync.PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      _extractedText = text.trim();
    } catch (_) {
      _extractedText = '(Could not extract text)';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pdfFile == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pdfName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('PDF'), icon: Icon(Icons.picture_as_pdf, size: 16)),
                  ButtonSegment(value: true, label: Text('Text'), icon: Icon(Icons.text_fields, size: 16)),
                ],
                selected: {_showText},
                onSelectionChanged: (v) => setState(() => _showText = v.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _pickAndLoad,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _showText ? _buildTextView() : _buildPdfView(),
        ),
      ],
    );
  }

  Widget _buildPdfView() {
    return PDFView(
      filePath: _pdfFile!.absolute.path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onError: (error) {
        setState(() => _error = error.toString());
      },
    );
  }

  Widget _buildTextView() {
    if (_extractedText.isEmpty) {
      return const Center(child: Text('No text extracted'));
    }
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _extractedText,
            style: const TextStyle(fontSize: 14, height: 1.6),
            onSelectionChanged: (selection, _) {
              if (selection != null && selection.start != selection.end) {
                final selected = _extractedText.substring(selection.start, selection.end).trim();
                if (selected.isNotEmpty && selected.split(RegExp(r'\s+')).length <= 5) {
                  _addWordFromSelection(selected);
                }
              }
            },
          ),
        ),
      ],
    );
  }

  void _addWordFromSelection(String word) {
    showDialog(
      context: context,
      builder: (_) => AddWordDialog(initialWord: word),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 80,
                color: Theme.of(context).colorScheme.primary.withAlpha(80)),
            const SizedBox(height: 16),
            Text(
              'Open a PDF to read',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'View formatted PDFs or extract text\nto add words to your vocabulary',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              FilledButton.icon(
                onPressed: _pickAndLoad,
                icon: const Icon(Icons.upload_file),
                label: const Text('Pick PDF'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
