import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Stand-in for the Mapbox map until Phase 02. Deliberately labeled so it is
/// never mistaken for a live map.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key, this.contentAlignment = Alignment.center});

  static const title = 'Map integration in Phase 02';

  final Alignment contentAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Map placeholder. $title.',
      child: CustomPaint(
        painter: const _GridPainter(),
        child: Align(
          alignment: contentAlignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BrandColors.surfaceRaised.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: BrandColors.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: BrandColors.mintSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PLACEHOLDER — NOT A MAP',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: BrandColors.emerald900,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Icon(
                        Icons.map_outlined,
                        size: 36,
                        color: BrandColors.emerald700,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: BrandColors.emerald900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'The interactive Mapbox map of Santa Ana, Pampanga '
                        'will appear here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: BrandColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint blueprint grid so the area reads as "map goes here" without
/// imitating streets or places.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  static const _cell = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9EFEB),
    );
    final minor = Paint()
      ..color = const Color(0xFFD9E3DD)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0xFFC9D7CF)
      ..strokeWidth = 1;
    var i = 0;
    for (var x = 0.0; x <= size.width; x += _cell, i++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 4 == 0 ? major : minor,
      );
    }
    i = 0;
    for (var y = 0.0; y <= size.height; y += _cell, i++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i % 4 == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
