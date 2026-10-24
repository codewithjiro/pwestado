import 'dart:math' as math;

import 'package:flutter/material.dart';

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
/// brand. Categories without their own hue use their group's, with their
/// own glyph, so every category has distinct art without image files.
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
      _ => (_groupHue(category.group), category.icon),
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

Color _groupHue(BusinessGroup group) => switch (group) {
  BusinessGroup.food => const Color(0xFFC4553D),
  BusinessGroup.everyday => const Color(0xFF1E8C84),
  BusinessGroup.personalCare => const Color(0xFFB4537E),
  BusinessGroup.lifestyle => const Color(0xFF7C5CB3),
  BusinessGroup.tech => const Color(0xFF3F6FC0),
  BusinessGroup.home => const Color(0xFFB0702E),
  BusinessGroup.vehicles => const Color(0xFF4F6A85),
  BusinessGroup.services => const Color(0xFF3F7CC0),
};

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
