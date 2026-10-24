import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/surfaces.dart';
import '../data/ai_insights_client.dart';
import '../data/ai_payload.dart';
import '../domain/ai_insight.dart';
import '../state/ai_insights_controller.dart';

abstract final class AiCopy {
  static const title = 'PWESTADO AI Insights';
  static const tagline = 'Understand your location, beyond the numbers.';
  static const ask = 'Ask AI to explain';
  static const askCompare = 'Ask AI to compare';
  static const askAgain = 'Ask again';
  static const label = 'AI-generated explanation based on available map data.';
  static const privacy =
      'Sends only the counts, distances and score on this screen. No business '
      'names, no exact location, nothing about you.';
  static const notAScore =
      'AI explains the evidence. It does not change your score or predict '
      'sales.';
  static const demo = 'DEMO INSIGHT · based on sample data';
  static const insufficient =
      'AI needs a complete score to explain. We couldn’t get enough '
      'information for this location yet.';
  static const loading = 'Writing a plain-language explanation…';
}

/// Explicit, optional AI explanation of an analysis that already exists.
///
/// [payload] is null when the evidence is not complete enough; the card
/// then explains why instead of offering a limited guess.
class AiInsightsCard extends ConsumerWidget {
  const AiInsightsCard({
    super.key,
    required this.payload,
    this.compare = false,
    this.unavailableMessage = AiCopy.insufficient,
  });

  final Map<String, Object?>? payload;
  final bool compare;

  /// Shown instead of the button when [payload] is null.
  final String unavailableMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = this.payload;
    final palette = context.palette;
    final configured = ref.watch(aiInsightsClientProvider).isConfigured;

    final Widget body;
    if (payload == null) {
      body = _Note(icon: Icons.info_outline, text: unavailableMessage);
    } else if (!configured) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FailureView(failure: AiFailure.notConfigured, onRetry: null),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: null,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(compare ? AiCopy.askCompare : AiCopy.ask),
          ),
        ],
      );
    } else {
      final key = AiPayload.keyOf(payload);
      final state = ref.watch(aiInsightsControllerProvider(key));
      final controller = ref.read(aiInsightsControllerProvider(key).notifier);
      void ask() => controller.request(payload);
      body = switch (state.status) {
        AiStatus.idle => _Idle(onAsk: ask, compare: compare),
        AiStatus.loading => _Loading(onCancel: controller.cancel),
        AiStatus.failed => _FailureView(
          failure: state.failure ?? AiFailure.unavailable,
          onRetry: (state.failure?.canRetry ?? false) ? ask : null,
        ),
        AiStatus.ready => _Result(insight: state.insight!, onAskAgain: ask),
      };
    }

    return AppCard(
      color: palette.aiContainer,
      borderColor: palette.aiBorder,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            icon: Icons.auto_awesome,
            title: AiCopy.title,
            subtitle: AiCopy.tagline,
            iconBackground: palette.surface,
            iconColor: palette.ai,
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: body,
          ),
        ],
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.onAsk, required this.compare});

  final VoidCallback onAsk;
  final bool compare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          compare
              ? 'Get a plain-language explanation of how the two locations '
                    'differ, what to watch out for, and what to check next.'
              : 'Get a plain-language explanation of this score, what to '
                    'watch out for, and what to check before you decide.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.ai,
            foregroundColor: context.palette.aiContainer,
          ),
          onPressed: onAsk,
          icon: const Icon(Icons.auto_awesome),
          label: Text(compare ? AiCopy.askCompare : AiCopy.ask),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(AiCopy.privacy, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AiCopy.loading, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            minHeight: 6,
            color: palette.ai,
            backgroundColor: palette.aiBorder,
            semanticsLabel: 'Waiting for AI explanation',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure, required this.onRetry});

  final AiFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              failure == AiFailure.notConfigured
                  ? Icons.cloud_off_outlined
                  : Icons.error_outline,
              color: context.palette.ai,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(failure.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(failure.message, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.insight, required this.onAskAgain});

  final AiInsight insight;
  final VoidCallback onAskAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            const StatusPill(
              label: 'AI-generated',
              icon: Icons.auto_awesome,
              tone: Tone.ai,
            ),
            if (insight.isDemo)
              const StatusPill(
                label: AiCopy.demo,
                icon: Icons.science_outlined,
                tone: Tone.sample,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          insight.quickAssessment,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        _Section(
          icon: Icons.thumb_up_alt_outlined,
          title: 'What looks promising',
          points: insight.promising,
        ),
        _Section(
          icon: Icons.visibility_outlined,
          title: 'What to watch out for',
          points: insight.watchOuts,
        ),
        _Section(
          icon: Icons.checklist_rounded,
          title: 'Practical next steps',
          points: insight.nextSteps,
        ),
        _Section(
          icon: Icons.info_outline,
          title: 'Data limitations',
          points: insight.limitations,
        ),
        const SizedBox(height: AppSpacing.md),
        Divider(color: palette.aiBorder, height: 1),
        const SizedBox(height: AppSpacing.sm),
        Text(AiCopy.label, style: theme.textTheme.labelMedium),
        Text(AiCopy.notAScore, style: theme.textTheme.bodySmall),
        Row(
          children: [
            Expanded(
              child: Text(
                '${insight.model} · ${TimeOfDay.fromDateTime(insight.generatedAt).format(context)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAskAgain,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(AiCopy.askAgain),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.points,
  });

  final IconData icon;
  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: palette.ai),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.ai,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(point, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.palette.ai),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
