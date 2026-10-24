import 'package:flutter/foundation.dart';

/// A validated PWESTADO AI Insights answer. Built only by [AiInsight.parse],
/// which rejects anything that does not match the contract, so the UI never
/// renders unchecked model output.
@immutable
class AiInsight {
  const AiInsight({
    required this.quickAssessment,
    required this.promising,
    required this.watchOuts,
    required this.nextSteps,
    required this.limitations,
    required this.isDemo,
    required this.model,
    required this.generatedAt,
  });

  static const maxSentence = 400;
  static const maxPoint = 280;

  /// One or two plain-language sentences.
  final String quickAssessment;

  /// Up to three evidence-grounded positives.
  final List<String> promising;

  /// Up to three realistic caveats.
  final List<String> watchOuts;

  /// Up to four practical checks before opening.
  final List<String> nextSteps;

  /// Up to three things the evidence cannot establish.
  final List<String> limitations;

  /// True when the evidence was SAMPLE DEMO DATA.
  final bool isDemo;
  final String model;
  final DateTime generatedAt;

  /// Validates the `{insight, model, demo}` body built from Gemini's answer. Throws
  /// [FormatException] on any contract violation.
  static AiInsight parse(
    Object? json, {
    required bool requestWasDemo,
    DateTime? now,
  }) {
    if (json is! Map) throw const FormatException('Body is not an object');
    final insight = json['insight'];
    if (insight is! Map) throw const FormatException('Missing insight');

    String sentence(Object? v, String field) {
      if (v is! String) throw FormatException('$field is not text');
      final t = _clean(v);
      if (t.isEmpty || t.length > maxSentence) {
        throw FormatException('$field has invalid length');
      }
      return t;
    }

    List<String> points(Object? v, String field, int max, {int min = 0}) {
      if (v is! List) throw FormatException('$field is not a list');
      final out = <String>[];
      for (final item in v) {
        if (item is! String) throw FormatException('$field item is not text');
        final t = _clean(item);
        if (t.isEmpty) continue;
        if (t.length > maxPoint) throw FormatException('$field item too long');
        out.add(t);
      }
      if (out.length < min || out.length > max) {
        throw FormatException('$field has ${out.length} items');
      }
      return List.unmodifiable(out);
    }

    final model = json['model'];
    return AiInsight(
      quickAssessment: sentence(insight['quickAssessment'], 'quickAssessment'),
      promising: points(insight['promising'], 'promising', 3),
      watchOuts: points(insight['watchOuts'], 'watchOuts', 3),
      nextSteps: points(insight['nextSteps'], 'nextSteps', 4, min: 1),
      limitations: points(insight['limitations'], 'limitations', 3, min: 1),
      // Demo status comes from what we sent; the model cannot clear it.
      isDemo: requestWasDemo || json['demo'] == true,
      model: model is String && model.length <= 64 ? model : 'Gemini',
      generatedAt: now ?? DateTime.now(),
    );
  }

  /// Strips control characters and markdown emphasis; collapses spaces.
  static String _clean(String s) => s
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]'), '')
      .replaceAll(RegExp(r'[*_`#]{1,3}'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Why an AI request did not produce an insight.
enum AiFailure {
  /// No Gemini API key in `gemini_local_key.dart` for this build.
  notConfigured,

  /// Gemini rejected the API key (invalid, revoked or not permitted).
  unauthorized,

  /// 429: short-window Gemini rate limit.
  rateLimited,

  /// Daily or prepaid quota of the API key is used up.
  quotaExhausted,

  /// 404: the configured Gemini model does not exist or was retired.
  modelUnavailable,

  /// Gemini unavailable (5xx).
  unavailable,
  timeout,
  offline,

  /// The answer did not match the contract.
  invalidResponse,

  /// Gemini refused the request as invalid (400).
  badRequest;

  /// Whether a "Try again" button makes sense.
  bool get canRetry => switch (this) {
    rateLimited || unavailable || timeout || offline || invalidResponse => true,
    notConfigured ||
    unauthorized ||
    quotaExhausted ||
    modelUnavailable ||
    badRequest => false,
  };

  String get title => switch (this) {
    notConfigured => 'AI Insights isn’t set up in this version',
    unauthorized => 'Gemini didn’t accept the API key',
    rateLimited => 'Too many AI requests right now',
    quotaExhausted => 'The Gemini API quota is used up',
    modelUnavailable => 'The AI model isn’t available',
    unavailable => 'AI service is unavailable',
    timeout => 'The AI took too long to answer',
    offline => 'No internet connection',
    invalidResponse => 'We couldn’t read the AI’s answer',
    badRequest => 'This analysis can’t be sent to AI',
  };

  String get message => switch (this) {
    notConfigured =>
      'Your score, map and comparison still work. AI explanations need a '
          'Gemini API key in this private demo build.',
    unauthorized =>
      'The key in this build is invalid or not allowed to use Gemini. Your '
          'score and evidence are unaffected.',
    rateLimited => 'Please wait about a minute, then try again.',
    quotaExhausted =>
      'This API key reached its Gemini quota. Try again later or tomorrow. '
          'Everything else keeps working.',
    modelUnavailable =>
      'Google no longer offers the Gemini model this build uses. Your score '
          'and evidence are unaffected.',
    unavailable => 'The AI service had a problem. Try again in a moment.',
    timeout => 'Try again in a moment. Your score is already complete.',
    offline => 'Connect to the internet, then try again.',
    invalidResponse =>
      'Nothing was shown, to avoid displaying an incomplete explanation. '
          'Try again.',
    badRequest => 'Try running the analysis again, then ask AI to explain.',
  };
}

class AiInsightException implements Exception {
  const AiInsightException(this.failure, {this.statusCode});

  final AiFailure failure;
  final int? statusCode;

  @override
  String toString() =>
      'AiInsightException(${failure.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'})';
}
