import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Draws the selected-site pin as PNG bytes for a Mapbox point annotation.
///
/// Emerald teardrop with a mint core, so it reads differently from the
/// orange competitor pins added later. The tip sits on the bottom edge of
/// the image; anchor the annotation at its bottom so the tip marks the exact
/// coordinate.
Future<Uint8List> renderSitePinPng({double pixelRatio = 3}) async {
  const width = 40.0;
  const height = 54.0;
  const center = Offset(width / 2, 19);
  const headRadius = 16.0;
  const tip = Offset(width / 2, height - 1.5);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);

  final body = Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: center, radius: headRadius)),
    Path()
      ..moveTo(center.dx - headRadius * 0.72, center.dy + headRadius * 0.69)
      ..lineTo(center.dx + headRadius * 0.72, center.dy + headRadius * 0.69)
      ..lineTo(tip.dx, tip.dy)
      ..close(),
  );

  canvas.drawShadow(body, const Color(0xFF0B3D2E), 3, false);
  canvas.drawPath(body, Paint()..color = BrandColors.emerald700);
  canvas.drawPath(
    body,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawCircle(center, 7, Paint()..color = BrandColors.mint);
  canvas.drawCircle(center, 3, Paint()..color = BrandColors.emerald900);

  final image = await recorder.endRecording().toImage(
    (width * pixelRatio).ceil(),
    (height * pixelRatio).ceil(),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
