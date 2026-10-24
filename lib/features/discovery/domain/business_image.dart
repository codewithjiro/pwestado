import 'package:flutter/foundation.dart';

/// Image references found in an OSM record. Only references that point to
/// freely licensed sources we can attribute are kept:
///
/// * `wikimedia_commons=File:…` or an `image=` URL on Wikimedia Commons:
///   a picture of this specific place, chosen by a mapper.
/// * `wikidata=Q…`: the Wikidata item for this specific place.
/// * `brand:wikidata=Q…`: the item for the brand/chain (e.g. Jollibee).
///   Anything found through it describes the brand, never this branch.
///
/// `image=` URLs on other hosts are ignored: their license is unknown.
@immutable
class BusinessImageRefs {
  const BusinessImageRefs({
    this.commonsFile,
    this.wikidata,
    this.brandWikidata,
    this.brandName,
  });

  /// A Commons file title without the `File:` prefix.
  final String? commonsFile;

  /// The place's own Wikidata id. Null when it equals [brandWikidata]
  /// (a common tagging mistake), so a brand item is never presented as the
  /// branch.
  final String? wikidata;
  final String? brandWikidata;
  final String? brandName;

  bool get hasBusinessRef => commonsFile != null || wikidata != null;
  bool get isEmpty => !hasBusinessRef && brandWikidata == null;

  String get cacheKey =>
      '${commonsFile ?? ''}|${wikidata ?? ''}|${brandWikidata ?? ''}';

  /// Extracts and validates references from raw OSM tags. Returns null when
  /// there is nothing usable.
  static BusinessImageRefs? fromTags(Map<String, String> tags) {
    final commons =
        _commonsTitle(tags['wikimedia_commons']) ??
        _commonsTitleFromUrl(tags['image']);
    final brandQ = _qid(tags['brand:wikidata']);
    var placeQ = _qid(tags['wikidata']);
    if (placeQ != null && placeQ == brandQ) placeQ = null;
    final refs = BusinessImageRefs(
      commonsFile: commons,
      wikidata: placeQ,
      brandWikidata: brandQ,
      brandName: tags['brand'],
    );
    return refs.isEmpty ? null : refs;
  }

  static final _qidPattern = RegExp(r'^Q[1-9]\d{0,11}$');

  static String? _qid(String? value) {
    final v = value?.trim();
    return v != null && _qidPattern.hasMatch(v) ? v : null;
  }

  static final _imageExt = RegExp(
    r'\.(jpe?g|png|webp|gif|svg|tiff?)$',
    caseSensitive: false,
  );

  /// `File:Name.jpg` (a Commons *category* or gallery is not a picture).
  static String? _commonsTitle(String? value) {
    var v = value?.trim();
    if (v == null || v.isEmpty) return null;
    if (v.startsWith('File:') || v.startsWith('Image:')) {
      v = v.substring(v.indexOf(':') + 1).trim();
    } else {
      return null;
    }
    return _cleanTitle(v);
  }

  static String? _commonsTitleFromUrl(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null || !uri.hasScheme) return null;
    if (uri.host == 'commons.wikimedia.org') {
      final segments = uri.pathSegments;
      if (segments.length == 2 && segments[0] == 'wiki') {
        return _commonsTitle(Uri.decodeComponent(segments[1]));
      }
      return null;
    }
    // https://upload.wikimedia.org/wikipedia/commons/a/ab/Name.jpg
    if (uri.host == 'upload.wikimedia.org' &&
        uri.pathSegments.length >= 5 &&
        uri.pathSegments[1] == 'commons' &&
        uri.pathSegments[2] != 'thumb') {
      return _cleanTitle(Uri.decodeComponent(uri.pathSegments.last));
    }
    return null;
  }

  static String? _cleanTitle(String title) {
    final t = title.replaceAll('_', ' ').trim();
    if (t.isEmpty || t.length > 240 || !_imageExt.hasMatch(t)) return null;
    return t;
  }

  @override
  bool operator ==(Object other) =>
      other is BusinessImageRefs && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}

/// What a resolved image depicts. Drives the caption, so a brand logo is
/// never presented as a photo of the branch.
enum BusinessImageKind {
  /// Linked from this place's own OSM record or Wikidata item.
  place,

  /// The brand's logo from its Wikidata item.
  brandLogo,

  /// A brand-level picture (may show a different branch).
  brandImage,
}

/// A licensed Wikimedia Commons image with what we need to credit it.
@immutable
class BusinessImage {
  const BusinessImage({
    required this.kind,
    required this.thumbnailUrl,
    required this.sourcePageUrl,
    required this.fileTitle,
    required this.license,
    this.author,
    this.licenseUrl,
  });

  final BusinessImageKind kind;

  /// A server-resized thumbnail (never the full-resolution original).
  final String thumbnailUrl;

  /// The Commons file page, which carries the full license and history.
  final String sourcePageUrl;
  final String fileTitle;

  /// Short license name, e.g. "CC BY-SA 4.0" or "Public domain".
  final String license;
  final String? author;
  final String? licenseUrl;

  bool get isBrandLevel => kind != BusinessImageKind.place;

  /// Plain-language label shown with the image.
  String get kindLabel => switch (kind) {
    BusinessImageKind.place => 'Photo linked to this place',
    BusinessImageKind.brandLogo => 'Brand logo, not a photo of this branch',
    BusinessImageKind.brandImage => 'Brand image, may show a different branch',
  };

  /// "Author · License · Wikimedia Commons".
  String get credit => [?author, license, 'Wikimedia Commons'].join(' · ');
}
