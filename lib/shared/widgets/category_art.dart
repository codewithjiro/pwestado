import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/business_category.dart';

/// Original PWESTADO category illustration: a tinted tile with the
/// category glyph and two soft decorative shapes. Drawn in code (no image
/// files, no third-party artwork, no licensing to track), so it renders
/// instantly, offline, at any size, in light and dark mode.
///
/// It represents the *category*, never a specific business.
class CategoryArt extends StatelessWidget {
  const CategoryArt({
    super.key,
    required this.category,
    this.size = 48,
    this.radius,
  });

  final BusinessCategory category;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final art = CategoryArtStyle.of(category, dark: dark);
    final r = radius ?? size * 0.28;
    return Semantics(
      label: '${category.label} illustration',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _ArtPainter(art),
            child: Center(
              child: Icon(art.glyph, size: size * 0.48, color: art.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hues chosen to feel like each trade (warm coffee, tomato red, sari-sari
/// teal, laundry blue, wheat gold) while staying calm next to the emerald
/// brand.
@immutable
class CategoryArtStyle {
  const CategoryArtStyle({
    required this.top,
    required this.bottom,
    required this.shape,
    required this.foreground,
    required this.glyph,
  });

  final Color top;
  final Color bottom;
  final Color shape;
  final Color foreground;
  final IconData glyph;

  static CategoryArtStyle of(BusinessCategory category, {required bool dark}) {
    final (Color hue, IconData glyph) = switch (category.id) {
      'coffee_shop' => (const Color(0xFF9A6A43), Icons.coffee_rounded),
      'restaurant' => (const Color(0xFFC4553D), Icons.ramen_dining_rounded),
      'convenience' => (const Color(0xFF1E8C84), Icons.storefront_rounded),
      'laundry' => (
        const Color(0xFF3F7CC0),
        Icons.local_laundry_service_rounded,
      ),
      'bakery' => (const Color(0xFFC08A2B), Icons.bakery_dining_rounded),
      _ => (BrandColors.emerald500, category.icon),
    };
    final hsl = HSLColor.fromColor(hue);
    if (dark) {
      return CategoryArtStyle(
        top: hsl
            .withLightness(0.24)
            .withSaturation(hsl.saturation * 0.6)
            .toColor(),
        bottom: hsl
            .withLightness(0.17)
            .withSaturation(hsl.saturation * 0.55)
            .toColor(),
        shape: hsl
            .withLightness(0.32)
            .withSaturation(hsl.saturation * 0.6)
            .toColor(),
        foreground: hsl.withLightness(0.82).toColor(),
        glyph: glyph,
      );
    }
    return CategoryArtStyle(
      top: hsl.withLightness(0.93).toColor(),
      bottom: hsl.withLightness(0.86).toColor(),
      shape: hsl.withLightness(0.80).withAlpha(0.7).toColor(),
      foreground: hsl.withLightness(0.32).toColor(),
      glyph: glyph,
    );
  }
}

class _ArtPainter extends CustomPainter {
  const _ArtPainter(this.art);

  final CategoryArtStyle art;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [art.top, art.bottom],
        ).createShader(rect),
    );
    final shape = Paint()..color = art.shape;
    final s = math.min(size.width, size.height);
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.08),
      s * 0.36,
      shape,
    );
    canvas.drawCircle(
      Offset(size.width * 0.06, size.height * 1.02),
      s * 0.28,
      shape..color = art.shape.withValues(alpha: art.shape.a * 0.7),
    );
  }

  @override
  bool shouldRepaint(_ArtPainter oldDelegate) => oldDelegate.art != art;
}
