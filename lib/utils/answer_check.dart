/// ─── Typing-mode Answer Check ───────────────────────────────────────
///
/// Pure answer-matching logic for the typing study mode, extracted from the
/// review UI so it can be unit-tested and reused.
///
/// Unicode-aware: it keeps letters of ANY script (Arabic, CJK, Cyrillic, …)
/// and digits, and drops punctuation/diacritic marks. An earlier `[a-z…]`
/// filter erased non-Latin answers to empty, so e.g. an Arabic translation
/// could never be marked correct — this normalization fixes that.

class AnswerCheck {
  /// Normalize a single answer/meaning for comparison: lowercase, drop a
  /// leading article, strip punctuation (keeping letters & digits of any
  /// script), and collapse whitespace.
  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'^(der|die|das|the|a|an|to)\s+'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// True if [typed] matches any of the comma / slash / semicolon-separated
  /// meanings in [translation]. Empty input never matches.
  static bool matches(String translation, String typed) {
    final t = normalize(typed);
    if (t.isEmpty) return false;
    final options = translation
        .split(RegExp(r'[,/;]'))
        .map(normalize)
        .where((e) => e.isNotEmpty);
    return options.contains(t);
  }
}
