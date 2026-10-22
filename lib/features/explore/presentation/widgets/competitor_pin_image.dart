import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Draws a competitor marker as PNG bytes for a Mapbox point annotation.
///
/// An orange disc with a white storefront glyph: round (not a teardrop) and
/// orange so it never reads as the emerald selected-site pin. The marker is
/// centered on its coordinate, so anchor the annotation at its center.
Future<Uint8List> renderCompetitorPinPng({double pixelRatio = 3}) async {
  const size = 30.0;
  const center = Offset(size / 2, size / 2);
  const radius = 12.5;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);

  final disc = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  canvas.drawShadow(disc, const Color(0xFF5A2A0A), 2, false);
  canvas.drawPath(disc, Paint()..color = BrandColors.competitorOrange);
  canvas.drawPath(
    disc,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2,
  );

  const icon = Icons.storefront;
  final glyph = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: 14,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
  glyph.dispose();

  final image = await recorder.endRecording().toImage(
    (size * pixelRatio).ceil(),
    (size * pixelRatio).ceil(),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
