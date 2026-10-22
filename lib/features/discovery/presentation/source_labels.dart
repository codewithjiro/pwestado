import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../domain/competitors.dart';

/// Small orange disc matching the map's competitor markers.
class CompetitorDot extends StatelessWidget {
  const CompetitorDot({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BrandColors.competitorOrange,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(Icons.storefront, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Pill telling live, cached, and sample data apart at a glance.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final DataSource source;

  @override
  Widget build(BuildContext context) {
    final (
      Color background,
      Color foreground,
      IconData icon,
    ) = switch (source) {
      DataSource.live => (
        BrandColors.emerald700,
        Colors.white,
        Icons.wifi_tethering,
      ),
      DataSource.cached => (
        BrandColors.mintSoft,
        BrandColors.emerald900,
        Icons.history,
      ),
      DataSource.sample => (
        SampleBanner.background,
        SampleBanner.foreground,
        Icons.science_outlined,
      ),
    };
    return Semantics(
      label: 'Data source: ${source.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              source.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Fetched 10:42 AM · OpenStreetMap via Overpass" (or the sample notice).
class SourceLine extends StatelessWidget {
  const SourceLine({super.key, required this.result});

  final CompetitorResult result;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: BrandColors.inkMuted);
    final when = formatFetchedAt(context, result.fetchedAt);
    final text = switch (result.source) {
      DataSource.live =>
        'Retrieved live $when · OpenStreetMap via Overpass API',
      DataSource.cached =>
        'Cached copy of a response retrieved $when '
            '(${_age(result.fetchedAt)}) · OpenStreetMap via Overpass API',
      DataSource.sample =>
        'Bundled sample created $when · not from OpenStreetMap',
    };
    return Text(text, style: style);
  }

  static String _age(DateTime fetchedAt) {
    final minutes = DateTime.now().difference(fetchedAt).inMinutes;
    return minutes < 1 ? 'under a minute ago' : '$minutes min ago';
  }
}

/// "at 10:42 AM", or "on 10/21 at 10:42 AM" when not today.
String formatFetchedAt(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final clock = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
  final now = DateTime.now();
  final sameDay =
      now.year == local.year &&
      now.month == local.month &&
      now.day == local.day;
  return sameDay ? 'at $clock' : 'on ${local.month}/${local.day} at $clock';
}

/// Unmissable label for fictional demo records.
class SampleBanner extends StatelessWidget {
  const SampleBanner({super.key});

  static const background = Color(0xFFFFF1C2);
  static const foreground = Color(0xFF6B4A00);
  static const title = 'SAMPLE DEMO DATA';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0xFFE2B93B), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Fictional places for demonstrating the app. Not from '
                  'OpenStreetMap and not real businesses.',
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
