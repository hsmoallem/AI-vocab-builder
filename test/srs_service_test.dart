// Unit tests for the SM-2 implementation in lib/services/srs_service.dart.
//
// These verify the algorithm against hand-computed expected values, the
// documented Anki multipliers, and edge cases (floors, caps, lapses).

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_vocab_builder/services/srs_service.dart';

void main() {
  // Fixed "now" so the nextDue timestamps in expectations are deterministic.
  final fixedNow = DateTime(2026, 7, 19, 12, 0, 0);

  group('SrsService.next — ease factor updates', () {
    test('Easy (q=5) leaves ease unchanged at 2.5', () {
      final s = SrsService.next(
        repetitions: 0,
        easeFactor: 2.5,
        interval: 0,
        rating: Rating.easy,
        now: fixedNow,
      );
      // EF' = 2.5 + (0.1 - 0*(0.08 + 0)) = 2.6
      expect(s.easeFactor, closeTo(2.6, 1e-9));
    });

    test('Good (q=4) leaves ease unchanged at 2.5', () {
      final s = SrsService.next(
        repetitions: 0,
        easeFactor: 2.5,
        interval: 0,
        rating: Rating.good,
        now: fixedNow,
      );
      // EF' = 2.5 + (0.1 - 1*(0.08 + 0.02)) = 2.5
      expect(s.easeFactor, closeTo(2.5, 1e-9));
    });

    test('Hard (q=3) decreases ease', () {
      final s = SrsService.next(
        repetitions: 0,
        easeFactor: 2.5,
        interval: 0,
        rating: Rating.hard,
        now: fixedNow,
      );
      // EF' = 2.5 + (0.1 - 2*(0.08 + 0.04)) = 2.5 + (0.1 - 0.24) = 2.36
      expect(s.easeFactor, closeTo(2.36, 1e-9));
    });

    test('Again (q=2) decreases ease more', () {
      final s = SrsService.next(
        repetitions: 0,
        easeFactor: 2.5,
        interval: 0,
        rating: Rating.again,
        now: fixedNow,
      );
      // EF' = 2.5 + (0.1 - 3*(0.08 + 0.06)) = 2.5 + (0.1 - 0.42) = 2.18
      expect(s.easeFactor, closeTo(2.18, 1e-9));
    });

    test('Ease never drops below 1.3 (SM-2 floor)', () {
      // Start at the floor and repeatedly rate Hard — should stay ≥ 1.3.
      var ease = 1.3;
      for (var i = 0; i < 5; i++) {
        final s = SrsService.next(
          repetitions: 3,
          easeFactor: ease,
          interval: 30,
          rating: Rating.again,
          now: fixedNow,
        );
        expect(s.easeFactor, greaterThanOrEqualTo(1.3));
        ease = s.easeFactor;
      }
    });
  });

  group('SrsService.next — interval progression (Good)', () {
    test('rep 1 → 1 day, rep 2 → 6 days, rep 3 → I_prev * EF', () {
      // First Good on a new card: reps 0 → 1, interval 0 → 1.
      var s = SrsService.next(
        repetitions: 0,
        easeFactor: 2.5,
        interval: 0,
        rating: Rating.good,
        now: fixedNow,
      );
      expect(s.repetitions, 1);
      expect(s.intervalDays, 1);

      // Second Good: reps 1 → 2, interval 1 → 6 (SM-2 fixed second step).
      s = SrsService.next(
        repetitions: s.repetitions,
        easeFactor: s.easeFactor,
        interval: s.intervalDays,
        rating: Rating.good,
        now: fixedNow,
      );
      expect(s.repetitions, 2);
      expect(s.intervalDays, 6);

      // Third Good: reps 2 → 3, interval 6 → 6 * 2.5 = 15.
      s = SrsService.next(
        repetitions: s.repetitions,
        easeFactor: s.easeFactor,
        interval: s.intervalDays,
        rating: Rating.good,
        now: fixedNow,
      );
      expect(s.repetitions, 3);
      expect(s.intervalDays, 15);

      // Fourth Good: 15 * 2.5 = 37.5 → 38 (rounded).
      s = SrsService.next(
        repetitions: s.repetitions,
        easeFactor: s.easeFactor,
        interval: s.intervalDays,
        rating: Rating.good,
        now: fixedNow,
      );
      expect(s.repetitions, 4);
      expect(s.intervalDays, inInclusiveRange(37, 38));
    });
  });

  group('SrsService.next — rating-specific multipliers', () {
    test('Hard grows slower than Good', () {
      const reps = 3;
      const ease = 2.5;
      const interval = 10;
      final hard = SrsService.next(
        repetitions: reps,
        easeFactor: ease,
        interval: interval,
        rating: Rating.hard,
        now: fixedNow,
      );
      final good = SrsService.next(
        repetitions: reps,
        easeFactor: ease,
        interval: interval,
        rating: Rating.good,
        now: fixedNow,
      );
      expect(hard.intervalDays, lessThanOrEqualTo(good.intervalDays));
      // Anki hard multiplier = 1.2, so 10 * 1.2 = 12.
      expect(hard.intervalDays, 12);
    });

    test('Easy grows faster than Good (easy bonus ×1.3)', () {
      final easy = SrsService.next(
        repetitions: 3,
        easeFactor: 2.5,
        interval: 10,
        rating: Rating.easy,
        now: fixedNow,
      );
      // After Easy, EF becomes 2.6, then interval = 10 * 2.6 * 1.3 = 33.8 → 34.
      expect(easy.intervalDays, 34);
      expect(easy.easeFactor, closeTo(2.6, 1e-9));
    });
  });

  group('SrsService.next — lapse handling', () {
    test('Again resets repetitions to 0 and interval to 0', () {
      final s = SrsService.next(
        repetitions: 5,
        easeFactor: 2.5,
        interval: 100,
        rating: Rating.again,
        now: fixedNow,
      );
      expect(s.repetitions, 0);
      expect(s.intervalDays, 0);
      // Card should be due immediately.
      expect(s.nextDue.difference(fixedNow).inSeconds, lessThan(1));
    });

    test('After a lapse, the next Good graduates to 1 day again', () {
      // Lapse first.
      var s = SrsService.next(
        repetitions: 5,
        easeFactor: 2.5,
        interval: 100,
        rating: Rating.again,
        now: fixedNow,
      );
      // Now graduate.
      s = SrsService.next(
        repetitions: s.repetitions,
        easeFactor: s.easeFactor,
        interval: s.intervalDays,
        rating: Rating.good,
        now: fixedNow,
      );
      expect(s.repetitions, 1);
      expect(s.intervalDays, 1);
    });
  });

  group('SrsService.next — interval cap', () {
    test('Interval is capped at 365 days', () {
      // 1-year interval, easy rating → would push way past the cap.
      final s = SrsService.next(
        repetitions: 10,
        easeFactor: 2.5,
        interval: 365,
        rating: Rating.easy,
        now: fixedNow,
      );
      expect(s.intervalDays, lessThanOrEqualTo(SrsService.maxIntervalDays));
    });
  });

  group('SrsService.next — timestamp correctness', () {
    test('nextDue equals now + intervalDays', () {
      final s = SrsService.next(
        repetitions: 2,
        easeFactor: 2.5,
        interval: 6,
        rating: Rating.good,
        now: fixedNow,
      );
      expect(s.lastReview, fixedNow);
      expect(s.nextDue, fixedNow.add(Duration(days: s.intervalDays)));
    });

    test('learning card (interval 0) is due immediately', () {
      final s = SrsService.next(
        repetitions: 0,
        easeFactor: 2.5,
        interval: 0,
        rating: Rating.again,
        now: fixedNow,
      );
      expect(s.intervalDays, 0);
      expect(s.nextDue.difference(fixedNow).inSeconds, lessThan(1));
    });
  });

  group('SrsService.previewInterval + hintForInterval', () {
    test('previewInterval matches next().intervalDays', () {
      final previewed = SrsService.previewInterval(
        repetitions: 3,
        easeFactor: 2.5,
        interval: 6,
        rating: Rating.good,
      );
      final actual = SrsService.next(
        repetitions: 3,
        easeFactor: 2.5,
        interval: 6,
        rating: Rating.good,
        now: fixedNow,
      ).intervalDays;
      expect(previewed, actual);
    });

    test('hint formatting is human-readable', () {
      expect(SrsService.hintForInterval(0), '<1m');
      expect(SrsService.hintForInterval(1), '1d');
      expect(SrsService.hintForInterval(6), '6d');
      expect(SrsService.hintForInterval(29), '29d');
      expect(SrsService.hintForInterval(30), '1mo');
      expect(SrsService.hintForInterval(365), '1y');
    });
  });
}
