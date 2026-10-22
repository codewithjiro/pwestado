import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'widgets/brand_header.dart';
import 'widgets/map_placeholder.dart';
import 'widgets/search_panel.dart';

/// Map-first home screen. Phones get a draggable bottom sheet over the map
/// area; wide screens (tablets, landscape) get a fixed side panel.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  static const _wideBreakpoint = 720.0;
  static const _sidePanelWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _wideBreakpoint) {
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _MapArea(contentAlignment: Alignment.center)),
                SizedBox(
                  width: _sidePanelWidth,
                  child: Material(
                    color: BrandColors.surfaceRaised,
                    elevation: 2,
                    child: SafeArea(left: false, child: SearchPanel()),
                  ),
                ),
              ],
            );
          }
          return Stack(
            children: [
              const Positioned.fill(
                child: _MapArea(contentAlignment: Alignment(0, -0.45)),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.54,
                minChildSize: 0.2,
                maxChildSize: 0.92,
                snap: true,
                snapSizes: const [0.54],
                builder: (context, scrollController) => _SheetSurface(
                  child: SearchPanel(
                    scrollController: scrollController,
                    showDragHandle: true,
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

class _MapArea extends StatelessWidget {
  const _MapArea({required this.contentAlignment});

  final Alignment contentAlignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: MapPlaceholder(contentAlignment: contentAlignment),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: BrandHeader(),
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
            color: Color(0x290B3D2E),
            blurRadius: 24,
            offset: Offset(0, -4),
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
