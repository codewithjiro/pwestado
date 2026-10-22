import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../saved/state/saved_analyses_controller.dart';
import 'about_sheet.dart';

/// Floating brand card shown over the map area: logo, wordmark, tagline,
/// and quick access to Saved Analyses and the About sheet.
class BrandHeader extends ConsumerWidget {
  const BrandHeader({super.key});

  static const tagline = 'Ang tamang pwesto, simula ng negosyo.';
  static const savedTooltip = 'Saved analyses';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savedCount = ref.watch(
      savedAnalysesControllerProvider.select((s) => s.items.length),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.floating,
      ),
      child: Material(
        color: BrandColors.surfaceRaised.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
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
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
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
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: savedTooltip,
                onPressed: () => context.push(AppRoutes.saved),
                icon: Badge(
                  isLabelVisible: savedCount > 0,
                  label: Text('$savedCount'),
                  backgroundColor: BrandColors.emerald700,
                  textColor: Colors.white,
                  child: const Icon(Icons.bookmarks_outlined),
                ),
                color: BrandColors.emerald700,
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
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.emerald700, BrandColors.emerald900],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.place_rounded, color: BrandColors.mint, size: 28),
          Positioned(
            bottom: 9,
            child: SizedBox(
              width: 14,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x668EE3C0),
                  borderRadius: BorderRadius.all(Radius.circular(1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
