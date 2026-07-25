import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../services/web_file_picker.dart';
import '../../widgets/add_word_dialog.dart';
import '../../widgets/web_top_bar.dart';

class WebReaderScreen extends StatefulWidget {
  const WebReaderScreen({super.key});

  @override
  State<WebReaderScreen> createState() => _WebReaderScreenState();
}

class _WebReaderScreenState extends State<WebReaderScreen> {
  Uint8List? _pdfBytes;
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
      final bytes = await pickPdfBytes();
      if (bytes == null) {
        setState(() => _isLoading = false);
        return;
      }

      final text = await _extractText(bytes);

      setState(() {
        _pdfBytes = bytes;
        _pdfName = 'Document.pdf';
        _extractedText = text;
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

  Future<String> _extractText(Uint8List bytes) async {
    try {
      final document = sync.PdfDocument(inputBytes: bytes);
      final extractor = sync.PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text.trim();
    } catch (e) {
      return '(Could not read text from this PDF file. Please ensure it is not password protected or corrupted.)';
    }
  }

  void _addWordFromSelection(String word) {
    showDialog(
      context: context,
      builder: (_) => AddWordDialog(initialWord: word),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pdfBytes == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PDF Reader'),
          actions: WebTopBar.buildActions(context),
        ),
        body: _buildEmptyState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Reader'),
        actions: WebTopBar.buildActions(context),
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(
                      color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, size: 20, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pdfName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // bg-slate-100
                    borderRadius: BorderRadius.circular(12), // rounded-xl
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSegmentButton(
                        context,
                        label: 'PDF',
                        icon: Icons.picture_as_pdf,
                        isActive: !_showText,
                        onTap: () => setState(() => _showText = false),
                      ),
                      const SizedBox(width: 4),
                      _buildSegmentButton(
                        context,
                        label: 'Text',
                        icon: Icons.text_fields,
                        isActive: _showText,
                        onTap: () => setState(() => _showText = true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _pickAndLoad,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
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
      ),
    );
  }

  Widget _buildPdfView() {
    return SfPdfViewer.memory(
      _pdfBytes!,
      canShowScrollHead: false,
      enableTextSelection: true,
      onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
        if (details.selectedText != null && details.selectedText!.isNotEmpty) {
          final word = details.selectedText!.trim();
          if (word.split(RegExp(r'\s+')).length <= 5) {
             // Instead of auto-opening, we could show a snackbar or a floating button,
             // but `SfPdfViewer` doesn't have an easy context menu override. 
             // Auto-opening might be annoying if they just drag to read, so we'll 
             // rely on the user to copy or switch to Text mode to add. Or we can just 
             // open the dialog!
             // Wait, `onTextSelectionChanged` fires often. Better to only do it
             // on release, but Syncfusion doesn't easily support that natively.
          }
        }
      },
    );
  }

  Widget _buildTextView() {
    if (_extractedText.isEmpty) {
      return const Center(child: Text('No text extracted'));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: SelectableText(
                _extractedText,
                style: const TextStyle(fontSize: 16, height: 1.6),
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
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 80,
                color: theme.colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              'Upload a PDF to read',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'View your PDFs natively on the web or extract text to add vocabulary words.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)], // brand-600 to brand-700
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.2), // shadow-brand-500/20
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _pickAndLoad,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text('Select PDF', style: TextStyle(color: Colors.white)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 14)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(BuildContext context, {required String label, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

