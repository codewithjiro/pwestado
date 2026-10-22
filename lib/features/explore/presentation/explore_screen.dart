import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme.dart';
import 'widgets/brand_header.dart';
import 'widgets/explore_map.dart';
import 'widgets/search_panel.dart';

/// Map-first home screen. Phones get a draggable bottom sheet over the map;
/// wide screens (tablets, landscape) get a fixed side panel.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  static const _wideBreakpoint = 720.0;
  static const _sidePanelWidth = 400.0;
  static const _sheetInitial = 0.54;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  /// Height of the map hidden behind the bottom sheet, in logical pixels.
  final _sheetCover = ValueNotifier<double>(0);
  static final _noCover = ValueNotifier<double>(0);

  @override
  void dispose() {
    _sheetCover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= ExploreScreen._wideBreakpoint) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _MapArea(bottomInset: _noCover)),
                const SizedBox(
                  width: ExploreScreen._sidePanelWidth,
                  child: Material(
                    color: BrandColors.surfaceRaised,
                    elevation: 2,
                    child: SafeArea(left: false, child: SearchPanel()),
                  ),
                ),
              ],
            );
          }

          final height = constraints.maxHeight;
          if (_sheetCover.value == 0) {
            _sheetCover.value = height * ExploreScreen._sheetInitial;
          }
          return Stack(
            children: [
              Positioned.fill(child: _MapArea(bottomInset: _sheetCover)),
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  _sheetCover.value = n.extent * height;
                  return false;
                },
                child: DraggableScrollableSheet(
                  initialChildSize: ExploreScreen._sheetInitial,
                  minChildSize: 0.2,
                  maxChildSize: 0.92,
                  snap: true,
                  snapSizes: const [ExploreScreen._sheetInitial],
                  builder: (context, scrollController) => _SheetSurface(
                    child: SearchPanel(
                      scrollController: scrollController,
                      showDragHandle: true,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The live map plus the floating brand header. Measures the header so the
/// map can keep Mapbox's logo and attribution visible just below it.
class _MapArea extends StatefulWidget {
  const _MapArea({required this.bottomInset});

  final ValueListenable<double> bottomInset;

  @override
  State<_MapArea> createState() => _MapAreaState();
}

class _MapAreaState extends State<_MapArea> {
  final _headerKey = GlobalKey();
  double _headerBottom = 0;

  void _measureHeader(Duration _) {
    if (!mounted) return;
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final bottom = box.size.height + MediaQuery.paddingOf(context).top;
    if ((bottom - _headerBottom).abs() > 0.5) {
      setState(() => _headerBottom = bottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback(_measureHeader);
    return Stack(
      children: [
        Positioned.fill(
          child: ExploreMap(
            topInset: _headerBottom,
            bottomInset: widget.bottomInset,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              key: _headerKey,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: const BrandHeader(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: BrandColors.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2E0B3D2E),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        child: child,
      ),
    );
  }
}
