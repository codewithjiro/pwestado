import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/models/search_radius.dart';
import '../../../../shared/widgets/surfaces.dart';

/// The chosen search distance as a compact field. Tapping it opens
/// [SearchDistanceSheet]. Changing the distance only updates the setting;
/// nothing is fetched until "Find nearby businesses".
class SearchDistanceField extends StatelessWidget {
  const SearchDistanceField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SearchRadius value;
  final ValueChanged<SearchRadius> onChanged;

  static const label = 'Search distance';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: ${value.label}. Tap to change.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () async {
          FocusScope.of(context).unfocus();
          final chosen = await showSearchDistanceSheet(context, current: value);
          if (chosen != null) onChanged(chosen);
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: label,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 10, 8, 10),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Icon(Icons.radar, size: 20, color: context.palette.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  value.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ),
              Icon(Icons.expand_more, color: context.palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves to the chosen distance (a preset, or a validated custom value
/// after Apply), or null when dismissed.
Future<SearchRadius?> showSearchDistanceSheet(
  BuildContext context, {
  required SearchRadius current,
}) {
  return showModalBottomSheet<SearchRadius>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SearchDistanceSheet(current: current),
  );
}

class SearchDistanceSheet extends StatefulWidget {
  const SearchDistanceSheet({super.key, required this.current});

  final SearchRadius current;

  static const title = 'Search distance';
  static const presetsLabel = 'Quick choices';
  static const customLabel = 'Custom';
  static const fieldLabel = 'Distance in meters';
  static const applyLabel = 'Apply distance';
  static const notSearchedYet =
      'Nothing is searched until you tap “Find nearby businesses”.';

  @override
  State<SearchDistanceSheet> createState() => _SearchDistanceSheetState();
}

class _SearchDistanceSheetState extends State<SearchDistanceSheet> {
  late final _controller = TextEditingController(
    text: widget.current.isPreset ? '' : '${widget.current.meters}',
  );

  /// Errors show once the user has typed or tried to apply, not on open.
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final input = SearchRadius.parse(_controller.text);
    if (input.radius case final radius?) {
      Navigator.of(context).pop(radius);
    } else {
      setState(() => _touched = true);
    }
  }

  void _useExample(int meters) {
    _controller.text = '$meters';
    setState(() => _touched = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final input = SearchRadius.parse(_controller.text);
    final radius = input.radius;
    final min = SearchRadius.format(SearchRadius.minMeters);
    final max = SearchRadius.format(SearchRadius.maxMeters);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(SearchDistanceSheet.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'How far from your location should we look for similar '
              'businesses? Straight-line distance, $min to $max.',
              style: mutedSmall(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            const EyebrowLabel(SearchDistanceSheet.presetsLabel),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final preset in SearchRadius.presets)
                  ChoiceChip(
                    label: Text(preset.label),
                    tooltip: 'Search within ${preset.label}',
                    selected: widget.current == preset,
                    showCheckmark: false,
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: widget.current == preset
                          ? p.onBrandFill
                          : p.textPrimary,
                    ),
                    onSelected: (_) => Navigator.of(context).pop(preset),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const EyebrowLabel(SearchDistanceSheet.customLabel),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 7,
              onChanged: (_) => setState(() => _touched = true),
              onSubmitted: (_) => _apply(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: SearchDistanceSheet.fieldLabel,
                hintText: 'e.g. 750',
                suffixText: 'm',
                counterText: '',
                helperText: 'Whole meters, $min–$max.',
                errorText: _touched ? input.error?.message : null,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Examples:', style: mutedSmall(context)),
                for (final meters in SearchRadius.examples)
                  ActionChip(
                    label: Text('$meters'),
                    tooltip: 'Use $meters meters',
                    onPressed: () => _useExample(meters),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              radius == null
                  ? SearchDistanceSheet.notSearchedYet
                  : 'Will search within ${radius.label}. '
                        '${SearchDistanceSheet.notSearchedYet}',
              style: mutedSmall(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _apply,
              child: const Text(SearchDistanceSheet.applyLabel),
            ),
          ],
        ),
      ),
    );
  }
}
