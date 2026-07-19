/// ─── CEFR Badge ─────────────────────────────────────────────────────
///
/// A small colored chip showing a word's CEFR level (A1–C2). Renders
/// nothing when the level is null/empty (not yet classified).

import 'package:flutter/material.dart';

class CefrBadge extends StatelessWidget {
  final String? level;
  final double fontSize;

  const CefrBadge(this.level, {super.key, this.fontSize = 11});

  // A-levels green, B-levels amber/orange, C-levels red — rough difficulty ramp.
  static Color _colorFor(String lvl) {
    switch (lvl.toUpperCase()) {
      case 'A1':
        return const Color(0xFF2E7D32);
      case 'A2':
        return const Color(0xFF558B2F);
      case 'B1':
        return const Color(0xFFF9A825);
      case 'B2':
        return const Color(0xFFEF6C00);
      case 'C1':
        return const Color(0xFFC62828);
      case 'C2':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF757575);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lvl = level?.trim().toUpperCase() ?? '';
    if (lvl.isEmpty) return const SizedBox.shrink();
    final color = _colorFor(lvl);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        lvl,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
