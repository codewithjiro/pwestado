import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/models/business_category.dart';
import '../../../../core/models/business_type_search.dart';
import '../../../../shared/widgets/category_art.dart';
import '../../../../shared/widgets/surfaces.dart';

/// Opens the searchable business type picker. Resolves to the chosen
/// category, or null when dismissed. Choosing never starts a search.
Future<BusinessCategory?> showBusinessTypePicker(
  BuildContext context, {
  required BusinessCategory current,
}) {
  return showModalBottomSheet<BusinessCategory>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BusinessTypePicker(current: current),
  );
}

class BusinessTypePicker extends StatefulWidget {
  const BusinessTypePicker({super.key, required this.current});

  final BusinessCategory current;

  static const title = 'Choose a business type';
  static const intro =
      'We’ll look for similar businesses listed on OpenStreetMap near your '
      'location. Search by name or a Filipino term, or browse below.';
  static const searchLabel = 'Search business types';
  static const searchHint = 'e.g. botika, barbershop, vulcanizing';
  static const otherTitle = 'Other business type';
  static const otherHint =
      'Not listed? Type what you plan to open and we’ll check whether the '
      'map has a reliable category for it.';
  static const unsupportedTitle = 'Not supported yet';
  static const relatedTitle = 'You can search these instead';

  static String checkOther(String text) => 'Check “$text”';
  static String noResults(String text) => 'No business types match “$text”.';

  @override
  State<BusinessTypePicker> createState() => _BusinessTypePickerState();
}

class _BusinessTypePickerState extends State<BusinessTypePicker> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  BusinessTypeResolution? _resolution;

  String get _query => _controller.text.trim();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String _) => setState(() => _resolution = null);

  void _clear() {
    _controller.clear();
    setState(() => _resolution = null);
  }

  void _checkOther() {
    _focus.unfocus();
    setState(() => _resolution = BusinessTypeSearch.resolve(_controller.text));
  }

  void _choose(BusinessCategory category) =>
      Navigator.of(context).pop(category);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final query = _query;
    final hits = BusinessTypeSearch.search(query);

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        // The space above the keyboard, so the list never hides under it.
        height: (MediaQuery.sizeOf(context).height - insets) * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    BusinessTypePicker.title,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _query.isEmpty ? null : _checkOther(),
                    onTapOutside: (_) => _focus.unfocus(),
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    maxLength: BusinessTypeSearch.maxInputLength,
                    decoration: InputDecoration(
                      labelText: BusinessTypePicker.searchLabel,
                      hintText: BusinessTypePicker.searchHint,
                      counterText: '',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: _clear,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xl,
                ),
                children: [
                  if (_resolution case final resolution?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.md,
                      ),
                      child: _ResolutionCard(
                        input: query,
                        resolution: resolution,
                        onChoose: _choose,
                      ),
                    ),
                  if (query.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        BusinessTypePicker.intro,
                        style: mutedSmall(context),
                      ),
                    ),
                    for (final group in BusinessGroup.values) ...[
                      _GroupHeader(group.label),
                      for (final hit in hits)
                        if (hit.category.group == group)
                          _CategoryTile(
                            hit: hit,
                            selected: hit.category == widget.current,
                            onTap: () => _choose(hit.category),
                          ),
                    ],
                    _OtherTile(
                      title: BusinessTypePicker.otherTitle,
                      subtitle: BusinessTypePicker.otherHint,
                      onTap: _focus.requestFocus,
                    ),
                  ] else ...[
                    if (hits.isNotEmpty)
                      _GroupHeader(
                        '${hits.length} matching '
                        '${hits.length == 1 ? 'type' : 'types'}',
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          BusinessTypePicker.noResults(query),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    for (final hit in hits)
                      _CategoryTile(
                        hit: hit,
                        showGroup: true,
                        selected: hit.category == widget.current,
                        onTap: () => _choose(hit.category),
                      ),
                    if (_resolution == null)
                      _OtherTile(
                        title: BusinessTypePicker.checkOther(query),
                        subtitle:
                            '${BusinessTypePicker.otherTitle}: see whether '
                            'PWESTADO can search for it.',
                        onTap: _checkOther,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Semantics(header: true, child: EyebrowLabel(label)),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.hit,
    required this.selected,
    required this.onTap,
    this.showGroup = false,
  });

  final CategoryHit hit;
  final bool selected;
  final bool showGroup;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = hit.category;
    final alias = hit.matchedAlias;
    final subtitle = [
      if (alias != null) 'Also called “$alias”',
      if (showGroup) category.group.label,
      if (alias == null && !showGroup) category.description,
    ].join(' · ');
    return ListTile(
      minTileHeight: 56,
      selected: selected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      selectedTileColor: context.palette.accentWash,
      selectedColor: context.palette.textPrimary,
      leading: CategoryArt(category: category, size: 40),
      title: Text(category.label),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: mutedSmall(context),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: context.palette.brand)
          : null,
      onTap: onTap,
    );
  }
}

class _OtherTile extends StatelessWidget {
  const _OtherTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: ListTile(
        minTileHeight: 56,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: context.palette.border),
        ),
        leading: CircleAvatar(
          backgroundColor: context.palette.accentWash,
          foregroundColor: context.palette.brand,
          child: const Icon(Icons.edit_note),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, style: mutedSmall(context)),
        onTap: onTap,
      ),
    );
  }
}

/// What an "other business type" resolved to.
class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({
    required this.input,
    required this.resolution,
    required this.onChoose,
  });

  final String input;
  final BusinessTypeResolution resolution;
  final ValueChanged<BusinessCategory> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (resolution) {
      case BusinessTypeMatch(:final category, :final exact):
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                exact
                    ? 'Supported business type'
                    : 'Closest supported business type',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  CategoryArt(category: category, size: 44),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      category.label,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(category.description, style: theme.textTheme.bodyMedium),
              if (!exact) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Based on “$input”. Please check this is what you mean.',
                  style: mutedSmall(context),
                ),
              ],
              if (category.coverageNote case final note?) ...[
                const SizedBox(height: AppSpacing.sm),
                InfoNote(icon: Icons.info_outline, lines: [note]),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => onChoose(category),
                child: Text('Use ${category.label}'),
              ),
            ],
          ),
        );
      case BusinessTypeAmbiguous(:final candidates):
        return _Choices(
          title: '“$input” could mean',
          categories: candidates,
          onChoose: onChoose,
        );
      case BusinessTypeUnsupported(:final message, :final related):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoNote(
              icon: Icons.info_outline,
              tone: NoteTone.warning,
              title: BusinessTypePicker.unsupportedTitle,
              lines: [
                message,
                'No search was run, so this does not mean there are zero '
                    'such businesses nearby.',
              ],
            ),
            if (related.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _Choices(
                title: BusinessTypePicker.relatedTitle,
                categories: related,
                onChoose: onChoose,
              ),
            ],
          ],
        );
      case BusinessTypeInvalid(:final message):
        return InfoNote(
          icon: Icons.error_outline,
          tone: NoteTone.danger,
          lines: [message],
        );
    }
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.title,
    required this.categories,
    required this.onChoose,
  });

  final String title;
  final List<BusinessCategory> categories;
  final ValueChanged<BusinessCategory> onChoose;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final category in categories)
            ListTile(
              minTileHeight: 52,
              contentPadding: EdgeInsets.zero,
              leading: CategoryArt(category: category, size: 36),
              title: Text(category.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onChoose(category),
            ),
        ],
      ),
    );
  }
}
