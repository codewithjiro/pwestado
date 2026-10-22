import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../comparison/domain/site_comparison.dart';

/// Body and letter colors of the Site A / Site B pins, shared with the
/// panel's slot badges so the list and the map match.
(Color, Color) compareSlotColors(CompareSlot slot) => switch (slot) {
  CompareSlot.a => (BrandColors.emerald900, BrandColors.mint),
  CompareSlot.b => (BrandColors.mint, BrandColors.emerald900),
};

/// Draws a lettered comparison pin ("A" or "B") as PNG bytes for a Mapbox
/// point annotation. Same teardrop shape as the selected-site pin, so it
/// reads as "a site", but with a letter instead of the mint core. The tip
/// is on the bottom edge: anchor the annotation at its bottom.
Future<Uint8List> renderComparePinPng(
  CompareSlot slot, {
  double pixelRatio = 3,
}) async {
  const width = 44.0;
  const height = 58.0;
  const center = Offset(width / 2, 21);
  const headRadius = 18.0;
  const tip = Offset(width / 2, height - 1.5);
  final (body, letter) = compareSlotColors(slot);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);

  final shape = Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: center, radius: headRadius)),
    Path()
      ..moveTo(center.dx - headRadius * 0.72, center.dy + headRadius * 0.69)
      ..lineTo(center.dx + headRadius * 0.72, center.dy + headRadius * 0.69)
      ..lineTo(tip.dx, tip.dy)
      ..close(),
  );

  canvas.drawShadow(shape, BrandColors.emerald900, 3, false);
  canvas.drawPath(shape, Paint()..color = body);
  canvas.drawPath(
    shape,
    Paint()
      ..color = slot == CompareSlot.a ? Colors.white : BrandColors.emerald900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round,
  );

  final text = TextPainter(
    text: TextSpan(
      text: slot.letter,
      style: TextStyle(
        color: letter,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  text.dispose();

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
