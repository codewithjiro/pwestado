import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../explore/presentation/widgets/about_sheet.dart';
import '../domain/place.dart';
import '../state/place_providers.dart';

/// Floating "Search a place or address" bar for the map. Searches only when
/// the user submits (keyboard search key or the search button), never per
/// keystroke. Results drop down under the bar.
class PlaceSearchBar extends ConsumerStatefulWidget {
  const PlaceSearchBar({super.key});

  static const hint = 'Search a place or address';

  @override
  ConsumerState<PlaceSearchBar> createState() => _PlaceSearchBarState();
}

class _PlaceSearchBarState extends ConsumerState<PlaceSearchBar> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    _focus.unfocus();
    ref.read(placeSearchControllerProvider.notifier).search(_text.text);
  }

  void _clear() {
    _text.clear();
    ref.read(placeSearchControllerProvider.notifier).close();
    setState(() {});
  }

  void _choose(PlaceResult place) {
    _focus.unfocus();
    _text.text = place.name;
    ref.read(placeSearchControllerProvider.notifier).choose(place);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(placeSearchControllerProvider);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: context.palette.floatingShadow,
          ),
          child: Material(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  _LogoButton(onPressed: () => showAboutSheet(context)),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) => setState(() {}),
                      style: theme.textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: PlaceSearchBar.hint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_text.text.isNotEmpty || search.isOpen)
                    IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      color: context.palette.textSecondary,
                      onPressed: _clear,
                    ),
                  IconButton.filled(
                    tooltip: 'Search',
                    style: IconButton.styleFrom(
                      backgroundColor: context.palette.brand,
                      foregroundColor: context.palette.onBrandFill,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.search),
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (search.isOpen) ...[
          const SizedBox(height: AppSpacing.sm),
          _Results(state: search, onChoose: _choose, onRetry: _submit),
        ],
      ],
    );
  }
}

class _LogoButton extends StatelessWidget {
  const _LogoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'About PWESTADO and its data',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BrandColors.emerald700, BrandColors.emerald900],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.place_rounded,
              // On the fixed emerald gradient in both themes.
              color: BrandColors.mint,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.state,
    required this.onChoose,
    required this.onRetry,
  });

  final PlaceSearchState state;
  final ValueChanged<PlaceResult> onChoose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );

    final Widget body = switch (state.status) {
      PlaceSearchStatus.loading => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Searching for "${state.query}"…'),
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(semanticsLabel: 'Searching places'),
          ],
        ),
      ),
      PlaceSearchStatus.empty => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'No places found for "${state.query}". Try a town, barangay or '
          'street name, or pick the spot on the map instead.',
        ),
      ),
      PlaceSearchStatus.error => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(state.failure!.message)),
            if (state.failure != GeocodingFailure.noToken &&
                state.failure != GeocodingFailure.unauthorized)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
      PlaceSearchStatus.results => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final place in state.results)
            ListTile(
              leading: Icon(
                place.isStreetLevel ? Icons.signpost_outlined : Icons.place,
                color: context.palette.brand,
              ),
              title: Text(place.name),
              subtitle: place.placeFormatted == null
                  ? null
                  : Text(place.placeFormatted!),
              onTap: () => onChoose(place),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              'Search by Mapbox. Results are places and addresses, not '
              'business listings.',
              style: muted,
            ),
          ),
        ],
      ),
      PlaceSearchStatus.idle => const SizedBox.shrink(),
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      child: Material(
        color: context.palette.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}
