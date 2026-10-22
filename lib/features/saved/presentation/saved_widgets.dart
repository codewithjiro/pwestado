import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../discovery/domain/competitors.dart';
import '../../discovery/presentation/source_labels.dart';
import '../domain/saved_analysis.dart';
import '../state/saved_analyses_controller.dart';

/// "Oct 22, 2026 · 10:00 AM" in the device's locale.
String formatSavedDate(BuildContext context, DateTime time) {
  final l10n = MaterialLocalizations.of(context);
  final local = time.toLocal();
  return '${l10n.formatShortDate(local)} · '
      '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// LIVE-SOURCED / CACHED / SAMPLE DEMO DATA, as it was when saved.
class SavedSourceBadge extends StatelessWidget {
  const SavedSourceBadge({super.key, required this.source});

  final DataSource source;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (source) {
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
      label: 'Saved data source: ${source.savedLabel}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                source.savedLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "HISTORICAL" marker used wherever a saved result appears next to
/// fresh ones.
class HistoricalPill extends StatelessWidget {
  const HistoricalPill({super.key});

  static const label = 'HISTORICAL';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BrandColors.sand,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: BrandColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.history_toggle_off,
            size: 13,
            color: BrandColors.ink,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BrandColors.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Deletes [id] and offers Undo, which restores the record with its
/// original id and timestamps.
Future<void> deleteSavedWithUndo(
  BuildContext context,
  WidgetRef ref,
  int id,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(savedAnalysesControllerProvider.notifier);
  Map<String, Object?>? row;
  try {
    row = await controller.delete(id);
  } on SavedAnalysisStorageException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (row == null) return;
  final deleted = row;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Saved analysis deleted.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await controller.undoDelete(deleted);
            } on SavedAnalysisStorageException catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(e.message)));
            }
          },
        ),
      ),
    );
}
