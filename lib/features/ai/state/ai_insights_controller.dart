import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_insights_client.dart';
import '../data/ai_payload.dart';
import '../domain/ai_insight.dart';

enum AiStatus { idle, loading, ready, failed }

@immutable
class AiInsightState {
  const AiInsightState({
    this.status = AiStatus.idle,
    this.insight,
    this.failure,
  });

  final AiStatus status;
  final AiInsight? insight;
  final AiFailure? failure;
}

/// One AI answer per evidence payload (keyed by [AiPayload.keyOf]), so a
/// new analysis never shows an explanation of older evidence. Requests are
/// sent only from [request], i.e. an explicit tap.
class AiInsightsController extends Notifier<AiInsightState> {
  AiInsightsController(this.key);

  final String key;
  CancelToken? _inFlight;

  @override
  AiInsightState build() {
    ref.onDispose(() => _inFlight?.cancel());
    return const AiInsightState();
  }

  Future<void> request(Map<String, Object?> payload) async {
    if (state.status == AiStatus.loading) return;
    final client = ref.read(aiInsightsClientProvider);
    if (!client.isConfigured) {
      state = const AiInsightState(
        status: AiStatus.failed,
        failure: AiFailure.notConfigured,
      );
      return;
    }
    final token = _inFlight = CancelToken();
    state = const AiInsightState(status: AiStatus.loading);
    try {
      final insight = await client.fetch(
        payload,
        isDemo: AiPayload.isDemo(payload),
        cancelToken: token,
      );
      if (!ref.mounted) return;
      state = AiInsightState(status: AiStatus.ready, insight: insight);
    } on AiInsightException catch (e) {
      if (!ref.mounted) return;
      state = AiInsightState(status: AiStatus.failed, failure: e.failure);
    } on DioException catch (e) {
      if (!ref.mounted || CancelToken.isCancel(e)) return;
      state = const AiInsightState(
        status: AiStatus.failed,
        failure: AiFailure.unavailable,
      );
    } finally {
      if (identical(_inFlight, token)) _inFlight = null;
    }
  }

  void cancel() {
    _inFlight?.cancel();
    _inFlight = null;
    if (ref.mounted) state = const AiInsightState();
  }
}

final aiInsightsControllerProvider = NotifierProvider.autoDispose
    .family<AiInsightsController, AiInsightState, String>(
      AiInsightsController.new,
    );
