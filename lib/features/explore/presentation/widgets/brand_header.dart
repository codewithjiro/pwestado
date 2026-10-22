import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import 'about_sheet.dart';

/// Floating brand card shown over the map area.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  static const tagline = 'Ang tamang pwesto, simula ng negosyo.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: BrandColors.surfaceRaised,
      elevation: 3,
      shadowColor: const Color(0x330B3D2E),
      borderRadius: BorderRadius.circular(AppRadius.md + 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            const _LogoMark(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PWESTADO',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: BrandColors.emerald900,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BrandColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'About PWESTADO and its data',
              icon: const Icon(Icons.info_outline),
              color: BrandColors.emerald700,
              onPressed: () => showAboutSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: BrandColors.emerald700,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(Icons.place, color: BrandColors.mint, size: 26),
    );
  }
}
