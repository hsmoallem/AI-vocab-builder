/// ─── Study Mode ─────────────────────────────────────────────────────
///
/// The four active-recall modes available on the Flashcards screen. The
/// mode is chosen at the start of a review session and applies to every
/// card in that session. Persisted to SharedPreferences as the default
/// for next time.
///
/// See [AppStrings.studyMode*] for localized labels and descriptions.

enum StudyMode {
  /// Show the source word. User flips to reveal translation + examples.
  flip,

  /// Show the source word. User must type the translation before reveal.
  typing,

  /// Show the translation. User recalls the source word.
  reverse,

  /// Show an example sentence with the target word blanked out.
  /// Falls back to [flip] for cards without an example sentence.
  cloze,
}

/// SharedPreferences key for the persisted default study mode.
const String kStudyModePrefKey = 'study_mode_default';
