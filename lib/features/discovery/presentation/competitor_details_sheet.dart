import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/geo.dart';
import '../domain/competitors.dart';
import 'business_thumbnail.dart';
import 'source_labels.dart';

/// Details of one mapped business: only what the source record contains.
Future<void> showCompetitorDetailsSheet(
  BuildContext context, {
  required NearbyBusiness business,
  required CompetitorResult result,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) =>
        _CompetitorDetails(business: business, result: result),
  );
}

class _CompetitorDetails extends StatelessWidget {
  const _CompetitorDetails({required this.business, required this.result});

  final NearbyBusiness business;
  final CompetitorResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    final category = result.query.category;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (business.isSample) ...[
                const SampleBanner(),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BusinessThumbnail(
                    business: business,
                    category: category,
                    size: 56,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          business.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontStyle: business.name == null
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatDistance(business.distanceMeters)} from '
                          'the site · ${category.label} '
                          '(${category.osmTag})',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (business.name == null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No name is recorded for this place in OpenStreetMap.',
                  style: muted,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              BusinessImageCredit(business: business),
              for (final MapEntry(:key, :value) in business.details.entries)
                _DetailRow(label: key, value: value),
              _DetailRow(
                label: 'Coordinates',
                value:
                    '${business.latitude.toStringAsFixed(5)}, '
                    '${business.longitude.toStringAsFixed(5)}',
              ),
              if (!business.isSample)
                _DetailRow(
                  label: 'Map record',
                  value: '${business.osmType} ${business.osmId}',
                ),
              const SizedBox(height: AppSpacing.md),
              SourceLine(result: result),
              const SizedBox(height: AppSpacing.sm),
              Text(
                business.isSample
                    ? 'Shown only to demonstrate the app when live data is '
                          'unavailable.'
                    : 'Being on the map doesn’t prove the business is open '
                          'today or how busy it is.',
                style: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
