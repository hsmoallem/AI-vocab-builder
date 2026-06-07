import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  File? _pdfFile;
  String _pdfName = '';
  String _extractedText = '';
  bool _isLoading = false;
  String? _error;

  Future<void> _pickAndExtract() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return; // User cancelled
      }

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      // Extract text from PDF
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();

      setState(() {
        _pdfFile = file;
        _pdfName = result.files.single.name;
        _extractedText = text.trim().isNotEmpty ? text : '(No text found in PDF)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to read PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pdfFile == null) {
      // No PDF loaded — show picker
      return _buildEmptyState();
    }

    return _buildReader();
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
              'Upload a PDF to read',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Extract text from any PDF and\nadd words to your vocabulary',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              FilledButton.icon(
                onPressed: _pickAndExtract,
                icon: const Icon(Icons.upload_file),
                label: const Text('Pick PDF'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReader() {
    return Column(
      children: [
        // PDF toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
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
              TextButton.icon(
                onPressed: _pickAndExtract,
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

        // Extracted text
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _extractedText.isEmpty
                  ? const Center(child: Text('No text extracted'))
                  : SelectableText(
                      _extractedText,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                      scrollPhysics: const BouncingScrollPhysics(),
                    ),
        ),
      ],
    );
  }
}
