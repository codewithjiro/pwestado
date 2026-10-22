import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/features/analysis/domain/suitability_scoring.dart';

const _competitors = CompetitorEvidence(
  distancesMeters: [100, 200, 600],
  radiusMeters: 1000,
);
const _complementary = ComplementaryEvidence(
  count: 6,
  radiusMeters: 1000,
  countsByKind: {'school': 3, 'bank': 2, 'pharmacy': 1},
);
const _roads = RoadEvidence(
  roadCount: 4,
  nearestRoadMeters: 30,
  nearestRoadKind: 'residential',
  nearestRoadName: 'Rizal Street',
  nearestMajorRoadMeters: 120,
);
const _full = ScoringInput(
  competitors: _competitors,
  complementary: _complementary,
  roads: _roads,
);

void main() {
  group('weights', () {
    test('are fixed at 40/30/30 and sum to 1', () {
      expect(Criterion.competitorProximity.weight, 0.40);
      expect(Criterion.complementary.weight, 0.30);
      expect(Criterion.roadAccess.weight, 0.30);
      expect(
        Criterion.values.fold(0.0, (s, c) => s + c.weight),
        closeTo(1, 1e-9),
      );
    });

    test('total is the weighted sum of criterion scores', () {
      final score = scoreSuitability(_full);
      // 0.40 × 75 + 0.30 × 12 + 0.30 × 100
      expect(score[Criterion.competitorProximity].score, 75);
      expect(score[Criterion.complementary].score, 12);
      expect(score[Criterion.roadAccess].score, 100);
      expect(score.total, 63.6);
      expect(score[Criterion.competitorProximity].contribution, 30);
      expect(score[Criterion.complementary].contribution, 3.6);
      expect(score[Criterion.roadAccess].contribution, 30);
      expect(score.formula, '0.40 × 75 + 0.30 × 12 + 0.30 × 100 = 63.6');
    });
  });

  group('competitor proximity', () {
    double score(List<double> d) => competitorCriterion(
      CompetitorEvidence(distancesMeters: d, radiusMeters: 1000),
    );

    test('zero mapped competitors scores 100', () => expect(score([]), 100));

    test('near competitors count 1.0, farther ones 0.5', () {
      expect(score([250]), 90); // boundary counts as near
      expect(score([251]), 95);
      expect(score([10, 900]), 85);
    });

    test('saturates at a weighted count of 10', () {
      expect(score(List.filled(10, 50)), 0);
      expect(score(List.filled(500, 50)), 0);
      expect(score(List.filled(20, 800)), 0);
      expect(score(List.filled(19, 800)), 5);
    });
  });

  group('complementary establishments', () {
    double score(int n, int radius) => complementaryCriterion(
      ComplementaryEvidence(count: n, radiusMeters: radius),
    );

    test('saturation scales with radius: 25 places per 500 m', () {
      expect(SuitabilityRules.complementarySaturation(500), 25);
      expect(SuitabilityRules.complementarySaturation(1000), 50);
      expect(SuitabilityRules.complementarySaturation(2000), 100);
    });

    test('scales linearly to 100 at saturation', () {
      expect(score(0, 1000), 0);
      expect(score(10, 1000), 20);
      expect(score(10, 500), 40);
      expect(score(50, 1000), 100);
      expect(score(1000, 2000), 100);
    });

    test('the rule shows the saturation used', () {
      final rule = scoreSuitability(_full)[Criterion.complementary].rule;
      expect(rule, contains('25 places per 500 m'));
      expect(rule, contains('(N = 50 here)'));
    });
  });

  group('road access proxy', () {
    double score({int count = 1, double? nearest, double? major}) =>
        roadCriterion(
          RoadEvidence(
            roadCount: count,
            nearestRoadMeters: nearest,
            nearestMajorRoadMeters: major,
          ),
        );

    test('no mapped road after a successful query scores 0', () {
      expect(score(count: 0), 0);
    });

    test('proximity points fall linearly from 50 m to 150 m', () {
      expect(score(nearest: 0), 60);
      expect(score(nearest: 50), 60);
      expect(score(nearest: 100), 30);
      expect(score(nearest: 150), 0);
    });

    test('a mapped major road within 150 m adds 40', () {
      expect(score(nearest: 20, major: 20), 100);
      expect(score(nearest: 100, major: 140), 70);
      expect(score(nearest: 100, major: 151), 30);
    });
  });

  group('missing evidence', () {
    test('a failed query yields no total, never a made-up zero', () {
      for (final input in const [
        ScoringInput(complementary: _complementary, roads: _roads),
        ScoringInput(competitors: _competitors, roads: _roads),
        ScoringInput(competitors: _competitors, complementary: _complementary),
        ScoringInput(),
      ]) {
        final score = scoreSuitability(input);
        expect(score.total, isNull);
        expect(score.hasTotal, isFalse);
        expect(score.formula, isNull);
        expect(score.warnings.first, startsWith('Insufficient data'));
      }
    });

    test('available criteria are still scored; missing ones are null', () {
      final score = scoreSuitability(
        const ScoringInput(competitors: _competitors),
      );
      expect(score[Criterion.competitorProximity].score, 75);
      expect(score[Criterion.complementary].score, isNull);
      expect(score[Criterion.complementary].contribution, isNull);
      expect(score[Criterion.roadAccess].score, isNull);
      expect(score[Criterion.roadAccess].evidence, contains('did not succeed'));
    });

    test('successful zero results are scored, not treated as missing', () {
      final score = scoreSuitability(
        const ScoringInput(
          competitors: CompetitorEvidence(
            distancesMeters: [],
            radiusMeters: 500,
          ),
          complementary: ComplementaryEvidence(count: 0, radiusMeters: 1000),
          roads: RoadEvidence(roadCount: 0),
        ),
      );
      // 0.40 × 100 + 0.30 × 0 + 0.30 × 0
      expect(score.total, 40);
      expect(score.lowConfidence, isTrue);
      expect(
        score.warnings,
        containsAll([
          contains('Low confidence: only 0 mapped places'),
          contains('Roads may exist but be unmapped'),
        ]),
      );
    });
  });

  group('confidence', () {
    test('sparse coverage is flagged low confidence', () {
      final score = scoreSuitability(
        const ScoringInput(
          competitors: CompetitorEvidence(
            distancesMeters: [300],
            radiusMeters: 1000,
          ),
          complementary: ComplementaryEvidence(count: 3, radiusMeters: 1000),
          roads: _roads,
        ),
      );
      expect(score.lowConfidence, isTrue);
      expect(score.warnings.single, contains('only 4 mapped places'));
    });

    test('truncated results are flagged', () {
      final score = scoreSuitability(
        const ScoringInput(
          competitors: _competitors,
          complementary: ComplementaryEvidence(
            count: 400,
            radiusMeters: 1000,
            possiblyTruncated: true,
          ),
          roads: _roads,
        ),
      );
      expect(score.lowConfidence, isTrue);
      expect(score.warnings.single, contains('server limit'));
    });

    test('well-covered evidence has no warnings', () {
      final score = scoreSuitability(_full);
      expect(score.lowConfidence, isFalse);
      expect(score.warnings, isEmpty);
    });
  });

  test('stays within 0..100 across extreme inputs', () {
    for (final competitors in [0, 1, 7, 40, 1000]) {
      for (final places in [0, 1, 15, 999]) {
        for (final nearest in [null, 0.0, 75.0, 149.0, 150.0]) {
          final score = scoreSuitability(
            ScoringInput(
              competitors: CompetitorEvidence(
                distancesMeters: List.filled(competitors, 120),
                radiusMeters: 2000,
              ),
              complementary: ComplementaryEvidence(
                count: places,
                radiusMeters: 1000,
              ),
              roads: RoadEvidence(
                roadCount: nearest == null ? 0 : 2,
                nearestRoadMeters: nearest,
                nearestMajorRoadMeters: nearest,
              ),
            ),
          );
          expect(score.total, inInclusiveRange(0, 100));
          for (final c in score.criteria) {
            expect(c.score, inInclusiveRange(0, 100));
          }
        }
      }
    }
  });

  test('identical evidence always yields an identical result', () {
    final a = scoreSuitability(_full);
    final b = scoreSuitability(
      const ScoringInput(
        competitors: CompetitorEvidence(
          distancesMeters: [100, 200, 600],
          radiusMeters: 1000,
        ),
        complementary: ComplementaryEvidence(
          count: 6,
          radiusMeters: 1000,
          countsByKind: {'school': 3, 'bank': 2, 'pharmacy': 1},
        ),
        roads: _roads,
      ),
    );
    expect(b.total, a.total);
    expect(b.formula, a.formula);
    for (final c in Criterion.values) {
      expect(b[c].score, a[c].score);
      expect(b[c].evidence, a[c].evidence);
      expect(b[c].rule, a[c].rule);
    }
  });

  test('evidence text reports only what was observed', () {
    final score = scoreSuitability(_full);
    expect(
      score[Criterion.competitorProximity].evidence,
      '3 mapped within 1 km (2 within 250 m); weighted count 2.5.',
    );
    expect(
      score[Criterion.complementary].evidence,
      '6 mapped places: 3 school, 2 bank, 1 pharmacy.',
    );
    expect(
      score[Criterion.roadAccess].evidence,
      'Nearest mapped road "Rizal Street" (residential) about 30 m away; '
      'mapped major road about 120 m away.',
    );
  });

  test('criterion meanings disclaim demand, traffic and travel time', () {
    expect(
      Criterion.complementary.meaning,
      contains('not customers or demand'),
    );
    expect(Criterion.roadAccess.meaning, contains('not travel time'));
    expect(
      Criterion.competitorProximity.meaning,
      contains('can also mean proven demand'),
    );
  });
}
