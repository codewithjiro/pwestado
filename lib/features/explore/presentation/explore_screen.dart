import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../places/presentation/place_search_bar.dart';
import '../state/explore_controller.dart';
import 'widgets/explore_map.dart';
import 'widgets/map_setup_card.dart';

/// MAPA tab: the live map with a place search bar on top and a compact
/// setup card at the bottom. Wide screens (tablets, landscape) show the
/// card as a side panel instead.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  static const _wideBreakpoint = 720.0;
  static const _sidePanelWidth = 380.0;

  /// The setup card never takes more than this share of the map's height;
  /// beyond it the card scrolls, so the map always stays usable.
  static const _maxCardShare = 0.6;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  /// Map height hidden behind the setup card, in logical pixels.
  final _cardCover = ValueNotifier<double>(0);
  static final _noCover = ValueNotifier<double>(0);

  final _headerKey = GlobalKey();
  final _cardKey = GlobalKey();
  double _headerBottom = 0;

  @override
  void dispose() {
    _cardCover.dispose();
    super.dispose();
  }

  /// Keeps the map's camera padding, floating buttons and Mapbox logo
  /// clear of the search bar and the card as their heights change.
  void _measure(Duration _) {
    if (!mounted) return;
    final header = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (header != null && header.hasSize) {
      final bottom = header.size.height + MediaQuery.paddingOf(context).top;
      if ((bottom - _headerBottom).abs() > 0.5) {
        setState(() => _headerBottom = bottom);
      }
    }
    final card = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    _cardCover.value = card != null && card.hasSize ? card.size.height : 0;
  }

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback(_measure);
    final picking = ref.watch(mapPickModeProvider);

    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = context.palette;
    // No app bar here, so set the status bar icons ourselves: dark icons
    // over the day map, light icons over the night map.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: palette.surface,
          ),
      child: Scaffold(
        // The keyboard covers the card instead of squeezing the map.
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= ExploreScreen._wideBreakpoint;
            final map = Stack(
              children: [
                Positioned.fill(
                  child: ExploreMap(
                    topInset: _headerBottom,
                    bottomInset: wide ? _noCover : _cardCover,
                  ),
                ),
                // Soft scrim so status bar icons stay readable over busy map
                // areas. Purely visual; taps pass through to the map.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.paddingOf(context).top + AppSpacing.xl,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            palette.background.withValues(alpha: 0.85),
                            palette.background.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      key: _headerKey,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: const PlaceSearchBar(),
                    ),
                  ),
                ),
                if (!wide && !picking)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ConstrainedBox(
                      key: _cardKey,
                      constraints: BoxConstraints(
                        maxHeight:
                            constraints.maxHeight * ExploreScreen._maxCardShare,
                      ),
                      child: const _CardSurface(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.md,
                          ),
                          child: MapSetupCard(),
                        ),
                      ),
                    ),
                  ),
              ],
            );

            if (!wide) return map;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: map),
                SizedBox(
                  width: ExploreScreen._sidePanelWidth,
                  child: Material(
                    color: context.palette.surface,
                    elevation: 2,
                    child: const SafeArea(
                      left: false,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: MapSetupCard(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, -4),
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
