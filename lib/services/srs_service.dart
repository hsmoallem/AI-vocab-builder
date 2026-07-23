/// ─── SRS Service — SM-2 Spaced Repetition Algorithm ────────────────
///
/// Pure-Dart implementation of the SuperMemo-2 (SM-2) algorithm with
/// Anki-style 4-button ratings (Again / Hard / Good / Easy). No Flutter
/// dependencies — trivially unit-testable.
///
/// ## Algorithm
/// Each card carries three persistent values:
///   - `repetitions` — consecutive successful reviews (resets on "Again")
///   - `easeFactor`  — how easy the card feels; starts at 2.5, floored at 1.3
///   - `interval`    — current interval in days
///
/// On each review, the user picks a rating. The new EF and interval are
/// computed deterministically:
///
///   q       = rating's quality grade (Again=2, Hard=3, Good=4, Easy=5)
///   EF'     = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))   (min 1.3)
///
///   if rating == Again:   repetitions = 0,  interval = 0
///   else:                 repetitions += 1
///                           interval  = [1, 6, I_prev * EF, ...]
///
/// Anki multipliers on top of SM-2:
///   Hard: interval = max(I_prev + 1, I_prev * 1.2)
///   Good: interval = I_prev * EF'                    (pure SM-2)
///   Easy: interval = I_prev * EF' * 1.3              (easy bonus)
///
/// ## Learning steps for new / lapsed cards
/// A card with interval == 0 is in "learning" state — it should be shown
/// again within minutes, not days. We model this as nextDue = now
/// (immediately due). After the first successful review it graduates to
/// a 1-day interval.
///
/// ## Interval cap
/// Intervals are capped at [maxIntervalDays] (default 365) to prevent
/// cards from effectively disappearing forever.

/// The four review ratings exposed in the UI.
///
/// Maps onto SM-2 quality grades (q): Again=2, Hard=3, Good=4, Easy=5.
/// We skip q=0 and q=1 (complete blackout variants) because a 4-button
/// UI is the industry standard (Anki, Quizlet, Memrise).
enum Rating {
  again, // q = 2 — forgot the word
  hard, //  q = 3 — remembered with significant difficulty
  good, //  q = 4 — remembered, maybe some hesitation
  easy, //  q = 5 — perfect, instant recall
}

/// Extension giving each [Rating] its SM-2 quality grade.
extension RatingQuality on Rating {
  /// SM-2 quality value q ∈ [0, 5].
  int get quality {
    switch (this) {
      case Rating.again:
        return 2;
      case Rating.hard:
        return 3;
      case Rating.good:
        return 4;
      case Rating.easy:
        return 5;
    }
  }
}

/// Immutable result of one SM-2 step. The caller persists these.
class SrsState {
  /// New consecutive-success count.
  final int repetitions;

  /// New easiness factor (always ≥ 1.3).
  final double easeFactor;

  /// New interval in days. 0 means "learning state, due immediately".
  final int intervalDays;

  /// When the card should next be shown.
  final DateTime nextDue;

  /// When this review happened.
  final DateTime lastReview;

  const SrsState({
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
    required this.nextDue,
    required this.lastReview,
  });
}

class SrsService {
  /// Maximum interval in days. Prevents cards from vanishing forever.
  static const int maxIntervalDays = 365;

  /// Minimum ease factor — SM-2 hard floor.
  static const double minEaseFactor = 1.3;

  /// Default ease for a brand-new card.
  static const double defaultEaseFactor = 2.5;

  /// Multiplier applied to Good (pure SM-2 path).
  static const double _goodMultiplier = 1.0;

  /// Hard interval multiplier (Anki default).
  static const double _hardMultiplier = 1.2;

  /// Easy bonus multiplier on top of SM-2 (Anki default).
  static const double _easyBonus = 1.3;

  /// Compute the next SRS state from the current state and the user's rating.
  ///
  /// All inputs are the card's pre-review values. Returns the post-review
  /// values the caller should persist.
  static SrsState next({
    required int repetitions,
    required double easeFactor,
    required int interval,
    required Rating rating,
    DateTime? now,
  }) {
    final reviewedAt = now ?? DateTime.now();
    final q = rating.quality;

    // ── Update ease factor ────────────────────────────────────────────
    // SM-2 formula. EF can never drop below 1.3.
    final newEase = _clampEase(
        easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)));

    // ── Update repetitions + interval ─────────────────────────────────
    int newReps;
    int newInterval;

    if (rating == Rating.again) {
      // Lapse — card goes back into the learning queue.
      newReps = 0;
      newInterval = 0;
    } else {
      newReps = repetitions + 1;
      newInterval = _intervalForRepetition(
        repetition: newReps,
        previousInterval: interval,
        ease: newEase,
        rating: rating,
      );
    }

    // Apply cap.
    if (newInterval > maxIntervalDays) newInterval = maxIntervalDays;

    // Compute next-due timestamp. interval == 0 → due now (learning state).
    final dueOffset = Duration(days: newInterval);
    final nextDue = reviewedAt.add(dueOffset);

    return SrsState(
      repetitions: newReps,
      easeFactor: newEase,
      intervalDays: newInterval,
      nextDue: nextDue,
      lastReview: reviewedAt,
    );
  }

  /// SM-2 interval branches, modified by Anki's Hard/Easy multipliers.
  static int _intervalForRepetition({
    required int repetition,
    required int previousInterval,
    required double ease,
    required Rating rating,
  }) {
    // First success after (re)learning.
    if (repetition == 1) {
      switch (rating) {
        case Rating.hard: return 1;
        case Rating.good: return 2;
        case Rating.easy: return 4;
        default: return 1;
      }
    }
    // Second success.
    if (repetition == 2) {
      switch (rating) {
        case Rating.hard: return 3;
        case Rating.good: return 6;
        case Rating.easy: return 8;
        default: return 6;
      }
    }

    // Subsequent successes grow the interval multiplicatively.
    // Apply rating-specific modifiers.
    double multiplier;
    switch (rating) {
      case Rating.hard:
        // Anki: max(I_prev + 1, I_prev * 1.2). The "+1" avoids stalling
        // when EF < 1.2 (which is impossible here since EF ≥ 1.3, but
        // kept for parity with Anki semantics).
        final grown = (previousInterval * _hardMultiplier).ceil();
        multiplier = grown > previousInterval + 1 ? grown.toDouble() : (previousInterval + 1).toDouble();
        return multiplier.toInt();
      case Rating.good:
        multiplier = ease * _goodMultiplier;
        break;
      case Rating.easy:
        multiplier = ease * _easyBonus;
        break;
      case Rating.again:
        // Unreachable — handled by the caller.
        return 0;
    }

    final next = (previousInterval * multiplier).round();
    // Always grow at least by one day so progress is visible.
    return next < previousInterval + 1 ? previousInterval + 1 : next;
  }

  static double _clampEase(double v) =>
      v < minEaseFactor ? minEaseFactor : v;

  /// Human-readable short hint for a rating button, e.g. "<1m", "6d", "4mo".
  ///
  /// Used in the UI to preview what each rating will do before the user
  /// taps it. Pure function — given the resulting state, format it.
  static String hintForInterval(int days) {
    if (days <= 0) return '<1m';
    if (days == 1) return '1d';
    if (days < 30) return '${days}d';
    if (days < 365) {
      final months = (days / 30).round();
      return '${months}mo';
    }
    final years = (days / 365).round();
    return '${years}y';
  }

  /// Preview the interval a specific rating would produce, WITHOUT mutating.
  ///
  /// Lets the UI show "<1m" / "6d" / "4mo" hints on each rating button.
  static int previewInterval({
    required int repetitions,
    required double easeFactor,
    required int interval,
    required Rating rating,
  }) {
    return next(
      repetitions: repetitions,
      easeFactor: easeFactor,
      interval: interval,
      rating: rating,
    ).intervalDays;
  }
}
