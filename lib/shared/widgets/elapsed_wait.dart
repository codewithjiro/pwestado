import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// "Waiting 23 s" — real time since the request started, refreshed every
/// second. Public Overpass servers often take 40-60 s, so this shows the
/// request is still alive without inventing a progress percentage.
class ElapsedWait extends StatefulWidget {
  const ElapsedWait({super.key});

  @override
  State<ElapsedWait> createState() => _ElapsedWaitState();
}

class _ElapsedWaitState extends State<ElapsedWait> {
  final _stopwatch = Stopwatch()..start();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Waiting ${_stopwatch.elapsed.inSeconds} s',
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: context.palette.textSecondary),
    );
  }
}
