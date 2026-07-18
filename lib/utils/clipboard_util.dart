/// ─── Clipboard helper ───────────────────────────────────────────────
///
/// Small shared utility so every "copy" button behaves the same:
/// copies trimmed text and shows a brief confirmation snackbar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  String? label,
}) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: trimmed));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(label == null ? 'Copied' : '$label copied'),
      duration: const Duration(milliseconds: 900),
    ),
  );
}
