import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/business_category.dart';
import '../../../shared/widgets/category_art.dart';
import '../data/business_image_repository.dart';
import '../data/overpass_client.dart';
import '../domain/business_image.dart';
import '../domain/competitors.dart';

/// A business's picture, in the documented fallback order:
///
/// 1. a licensed image linked to this specific place,
/// 2. a licensed brand logo/image, marked "Brand" so it is never mistaken
///    for this branch,
/// 3. the category illustration (also shown instantly while loading and
///    whenever a lookup or download fails).
///
/// Records without image references never trigger a network request.
class BusinessThumbnail extends ConsumerWidget {
  const BusinessThumbnail({
    super.key,
    required this.business,
    required this.category,
    this.size = 52,
  });

  final NearbyBusiness business;
  final BusinessCategory category;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refs = business.imageRefs;
    final art = CategoryArt(category: category, size: size);
    if (refs == null || business.isSample) return art;

    final image = ref.watch(businessImageProvider(refs)).value;
    if (image == null) return art;
    return _NetworkThumb(
      image: image,
      size: size,
      fallback: art,
      semanticLabel: '${image.kindLabel}: ${business.displayName}',
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  const _NetworkThumb({
    required this.image,
    required this.size,
    required this.fallback,
    required this.semanticLabel,
  });

  final BusinessImage image;
  final double size;
  final Widget fallback;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logo = image.kind == BusinessImageKind.brandLogo;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.28),
            child: ColoredBox(
              // Logos are often transparent; give them a neutral backdrop.
              color: logo ? Colors.white : palette.surfaceMuted,
              child: Padding(
                padding: EdgeInsets.all(logo ? size * 0.12 : 0),
                child: Image.network(
                  image.thumbnailUrl,
                  headers: const {'User-Agent': OverpassConfig.userAgent},
                  // Decode at display size: keeps memory small in long lists.
                  cacheWidth: (size * dpr).round(),
                  fit: logo ? BoxFit.contain : BoxFit.cover,
                  semanticLabel: semanticLabel,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, sync) => sync
                      ? child
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: frame == null ? fallback : child,
                        ),
                  errorBuilder: (context, error, stack) => fallback,
                ),
              ),
            ),
          ),
          if (image.isBrandLevel && size >= 44)
            Positioned(
              left: 3,
              bottom: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: palette.surfaceElevated.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Brand',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The detail sheet's image block: the picture plus what it shows and who
/// made it. Renders nothing when there is no licensed image.
class BusinessImageCredit extends ConsumerWidget {
  const BusinessImageCredit({super.key, required this.business});

  final NearbyBusiness business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refs = business.imageRefs;
    if (refs == null || business.isSample) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final image = ref.watch(businessImageProvider(refs)).value;
    if (image == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: [
            _NetworkThumb(
              image: image,
              size: 72,
              fallback: const SizedBox.shrink(),
              semanticLabel: image.kindLabel,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(image.kindLabel, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(image.credit, style: theme.textTheme.bodySmall),
                  SelectableText(
                    image.sourcePageUrl,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.palette.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
