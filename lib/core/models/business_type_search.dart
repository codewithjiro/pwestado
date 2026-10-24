import 'business_category.dart';

/// Finding a [BusinessCategory] from what a beginner types.
///
/// Everything here is a local lookup in the verified catalog. Typed text is
/// never turned into an OSM tag or a query, and nothing is guessed: input
/// that does not match a known name or alias is reported as unsupported.
abstract final class BusinessTypeSearch {
  /// Longest text accepted as an "other business type".
  static const maxInputLength = 60;

  /// Lowercase, accents and punctuation removed, single spaces:
  /// "Sari-Sari Café!" -> "sari sari cafe".
  static String normalize(String text) {
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final plain = _accents[ch] ?? ch;
      buffer.write(_plainChar.hasMatch(plain) ? plain : ' ');
    }
    return buffer.toString().trim().replaceAll(_spaces, ' ');
  }

  static final _plainChar = RegExp(r'^[a-z0-9]$');
  static final _spaces = RegExp(r'\s+');

  /// Categories matching [query], best first. Empty query: all, in catalog
  /// order. Each hit carries the alias that matched, if not the label.
  static List<CategoryHit> search(String query) {
    final q = normalize(query);
    if (q.isEmpty) {
      return [for (final c in BusinessCategory.all) CategoryHit(c, 0)];
    }
    final hits = <CategoryHit>[];
    for (final category in BusinessCategory.all) {
      var best = 0;
      String? matched;
      for (final term in _terms(category)) {
        final score = _score(q, term.text);
        if (score > best) {
          best = score;
          matched = term.isLabel ? null : term.text;
        }
      }
      if (best > 0) {
        hits.add(CategoryHit(category, best, matchedAlias: matched));
      }
    }
    // Stable sort: equal scores keep catalog order.
    final indexed = hits.indexed.toList()
      ..sort((a, b) {
        final byScore = b.$2.score.compareTo(a.$2.score);
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    return [for (final (_, hit) in indexed) hit];
  }

  /// Resolves free text entered as "Other business type".
  static BusinessTypeResolution resolve(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const BusinessTypeInvalid(
        'Type the kind of business you plan to open.',
      );
    }
    if (trimmed.length > maxInputLength) {
      return const BusinessTypeInvalid(
        'That’s too long. Use a short name, like “printing shop”.',
      );
    }
    final q = normalize(trimmed);
    if (!RegExp(r'[a-z]{2}').hasMatch(q)) {
      return const BusinessTypeInvalid(
        'Use words, for example “water refilling station”.',
      );
    }

    // 1. The whole input is a category name or alias.
    for (final category in BusinessCategory.all) {
      for (final term in _terms(category)) {
        if (term.text == q) return BusinessTypeMatch(category, exact: true);
      }
    }

    // 2. A trade we know has no reliable map category.
    for (final entry in _unsupported) {
      if (entry.phrases.any((p) => _containsPhrase(q, p))) {
        return BusinessTypeUnsupported(
          message: entry.message,
          related: [
            for (final id in entry.relatedIds) ?BusinessCategory.byId(id),
          ],
        );
      }
    }

    // 3. The input contains a specific alias ("motorcycle parts shop").
    var longest = 0;
    final candidates = <BusinessCategory>{};
    for (final category in BusinessCategory.all) {
      for (final term in _terms(category)) {
        final t = term.text;
        if (t.length < 4 || !_containsPhrase(q, t)) continue;
        if (t.length > longest) {
          longest = t.length;
          candidates
            ..clear()
            ..add(category);
        } else if (t.length == longest) {
          candidates.add(category);
        }
      }
    }
    if (candidates.length == 1) {
      return BusinessTypeMatch(candidates.single, exact: false);
    }
    if (candidates.length > 1) {
      return BusinessTypeAmbiguous(candidates.toList());
    }

    // 4. Nothing reliable: say so, and offer categories that share a word.
    final words = q
        .split(' ')
        .where((w) => w.length >= 3 && !_genericWords.contains(w))
        .toSet();
    final related = <BusinessCategory>[];
    for (final category in BusinessCategory.all) {
      final shares = _terms(category).any(
        (term) => term.text
            .split(' ')
            .any((w) => words.any((typed) => w.startsWith(typed))),
      );
      if (shares) related.add(category);
      if (related.length == 3) break;
    }
    return BusinessTypeUnsupported(
      message: genericUnsupported,
      related: related,
    );
  }

  static const genericUnsupported =
      'PWESTADO can’t search nearby businesses for this type yet, because we '
      'don’t have a reliable OpenStreetMap category for it. Searching with a '
      'guessed category could show unrelated businesses as competitors.';

  static Iterable<_Term> _terms(BusinessCategory category) sync* {
    yield _Term(normalize(category.label), isLabel: true);
    for (final part in category.label.split('/')) {
      yield _Term(normalize(part), isLabel: true);
    }
    for (final alias in category.aliases) {
      yield _Term(normalize(alias), isLabel: false);
    }
  }

  static int _score(String q, String term) {
    if (term.isEmpty) return 0;
    if (term == q) return 100;
    if (term.startsWith(q)) return 80;
    final words = term.split(' ');
    final typed = q.split(' ');
    // Every typed word starts some word of the term: "hair sal" -> salon.
    if (typed.every((t) => words.any((w) => w.startsWith(t)))) return 60;
    if (q.length >= 3 && term.contains(q)) return 40;
    return 0;
  }

  /// Whole-word containment: "printing shop near me" contains "printing".
  static bool _containsPhrase(String text, String phrase) =>
      ' $text '.contains(' $phrase ');

  static const _accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  /// Words too general to suggest a category on their own.
  static const _genericWords = {
    'shop',
    'store',
    'station',
    'center',
    'centre',
    'service',
    'services',
    'business',
    'tindahan',
    'and',
    'the',
    'for',
    'ng',
    'sa',
  };

  /// Trades people ask about that have no specific, documented OSM tag in
  /// this catalog. Checked before partial alias matches, so "computer
  /// rental for events" or "LPG gas" never fall through to a wrong category.
  static const _unsupported = [
    _Unsupported(
      phrases: ['bigasan', 'rice store', 'rice retail', 'rice dealer', 'bigas'],
      message:
          'Rice stores don’t have their own OpenStreetMap category in '
          'PWESTADO yet. Many are mapped as general or convenience stores.',
      relatedIds: ['convenience', 'supermarket', 'variety_store'],
    ),
    _Unsupported(
      phrases: ['lpg', 'gasul', 'cooking gas', 'gas refill', 'lpg refill'],
      message:
          'LPG dealers use a different map category from gas stations, and '
          'PWESTADO doesn’t search it yet.',
      relatedIds: ['hardware', 'convenience'],
    ),
    _Unsupported(
      phrases: [
        'food cart',
        'food stall',
        'street food',
        'food truck',
        'foodcart',
      ],
      message:
          'Food carts and stalls are rarely on OpenStreetMap, so searching '
          'for them would miss most real ones.',
      relatedIds: ['fast_food', 'restaurant'],
    ),
    _Unsupported(
      phrases: [
        'online shop',
        'online store',
        'online selling',
        'online business',
        'reseller',
        'home based',
      ],
      message:
          'Online and home-based businesses aren’t mapped as storefronts, so '
          'nearby-business search can’t count them.',
      relatedIds: [],
    ),
    _Unsupported(
      phrases: ['school supplies', 'school supply', 'stationery'],
      message: 'School supply stores aren’t supported in PWESTADO yet.',
      relatedIds: ['bookstore', 'printing', 'variety_store'],
    ),
    _Unsupported(
      phrases: ['tailor', 'tailoring', 'patahian', 'sastre', 'modista'],
      message:
          'Tailors are mapped in more than one way on OpenStreetMap, so '
          'PWESTADO can’t count them reliably yet.',
      relatedIds: ['clothing'],
    ),
    _Unsupported(
      phrases: ['lechon', 'lechonan', 'litson'],
      message: 'Lechon sellers don’t have their own map category.',
      relatedIds: ['restaurant', 'meat_shop'],
    ),
    _Unsupported(
      phrases: ['frozen food', 'frozen foods', 'frozen goods'],
      message: 'Frozen food stores don’t have their own map category yet.',
      relatedIds: ['supermarket', 'meat_shop', 'convenience'],
    ),
    _Unsupported(
      phrases: [
        'e load',
        'eload',
        'loading station',
        'gcash',
        'remittance',
        'money transfer',
        'padala',
        'bayad center',
        'bills payment',
      ],
      message:
          'Load, remittance and bills-payment outlets aren’t supported yet; '
          'many operate inside other stores.',
      relatedIds: ['pawnshop', 'convenience'],
    ),
    _Unsupported(
      phrases: ['palengke', 'wet market', 'talipapa', 'public market'],
      message:
          'Markets are already counted as helpful places nearby in the score, '
          'not as competitors.',
      relatedIds: ['supermarket', 'meat_shop'],
    ),
    _Unsupported(
      phrases: [
        'junk shop',
        'junkshop',
        'scrap',
        'tutorial',
        'tutoring',
        'review center',
        'daycare',
        'day care',
        'boarding house',
        'dormitory',
        'dorm',
        'apartment',
        'catering',
        'photo studio',
        'photography',
        'car rental',
        'van rental',
        'hotel',
        'resort',
        'videoke',
        'karaoke',
        'bar',
        'bank',
      ],
      message: genericUnsupported,
      relatedIds: [],
    ),
    _Unsupported(
      phrases: [
        'dentist',
        'dental',
        'medical clinic',
        'health center',
        'doctor',
        'laboratory',
      ],
      message:
          'Clinics and health professionals aren’t supported as business '
          'types; clinics are counted as helpful places nearby instead.',
      relatedIds: ['pharmacy', 'optical_shop'],
    ),
    _Unsupported(
      phrases: ['veterinary', 'veterinarian', 'vet clinic', 'animal clinic'],
      message: 'Veterinary clinics aren’t supported as a business type yet.',
      relatedIds: ['pet_shop'],
    ),
    _Unsupported(
      phrases: ['piso wifi', 'pisowifi', 'wifi vendo'],
      message:
          'Piso WiFi machines aren’t mapped as businesses on OpenStreetMap.',
      relatedIds: ['internet_cafe'],
    ),
  ];
}

class _Term {
  const _Term(this.text, {required this.isLabel});

  final String text;
  final bool isLabel;
}

class _Unsupported {
  const _Unsupported({
    required this.phrases,
    required this.message,
    required this.relatedIds,
  });

  final List<String> phrases;
  final String message;
  final List<String> relatedIds;
}

/// One search result: the category and how well it matched.
class CategoryHit {
  const CategoryHit(this.category, this.score, {this.matchedAlias});

  final BusinessCategory category;
  final int score;

  /// The alias that matched, when it was not the category's own label.
  final String? matchedAlias;
}

/// The outcome of [BusinessTypeSearch.resolve].
sealed class BusinessTypeResolution {
  const BusinessTypeResolution();
}

/// A supported category. The user still confirms it before it is used.
final class BusinessTypeMatch extends BusinessTypeResolution {
  const BusinessTypeMatch(this.category, {required this.exact});

  final BusinessCategory category;

  /// False when only part of the input matched ("motorcycle parts shop").
  final bool exact;
}

/// More than one category matched equally; the user picks one.
final class BusinessTypeAmbiguous extends BusinessTypeResolution {
  const BusinessTypeAmbiguous(this.candidates);

  final List<BusinessCategory> candidates;
}

/// No reliable map category. Never searched, never shown as zero results.
final class BusinessTypeUnsupported extends BusinessTypeResolution {
  const BusinessTypeUnsupported({required this.message, required this.related});

  final String message;

  /// Supported categories worth considering instead; may be empty.
  final List<BusinessCategory> related;
}

/// Empty, too long, or not words.
final class BusinessTypeInvalid extends BusinessTypeResolution {
  const BusinessTypeInvalid(this.message);

  final String message;
}
