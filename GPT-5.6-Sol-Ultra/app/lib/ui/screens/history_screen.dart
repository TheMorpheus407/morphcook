import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/local_state.dart';
import '../../domain/models/recipe.dart';
import '../../l10n/app_strings.dart';
import '../../services/pagination_controller.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';

class CookingHistoryScreen extends StatefulWidget {
  const CookingHistoryScreen({
    required this.entries,
    required this.recipesById,
    required this.languageCode,
    required this.onOpenRecipe,
    super.key,
  });

  final List<CookHistoryEntry> entries;
  final Map<String, Recipe> recipesById;
  final String languageCode;
  final ValueChanged<Recipe> onOpenRecipe;

  @override
  State<CookingHistoryScreen> createState() => _CookingHistoryScreenState();
}

class _CookingHistoryScreenState extends State<CookingHistoryScreen> {
  late PaginationController<CookHistoryEntry> _pagination;

  @override
  void initState() {
    super.initState();
    _pagination = _create()..addListener(_changed);
    unawaited(_pagination.loadMore());
  }

  @override
  void didUpdateWidget(covariant CookingHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!const IterableEquality<String>().equals(
      oldWidget.entries.map((entry) => entry.id),
      widget.entries.map((entry) => entry.id),
    )) {
      final old = _pagination;
      old.removeListener(_changed);
      _pagination = _create()..addListener(_changed);
      old.dispose();
      unawaited(_pagination.loadMore());
    }
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  PaginationController<CookHistoryEntry> _create() {
    final grouped = <DateTime, List<CookHistoryEntry>>{};
    for (final entry in widget.entries) {
      grouped.putIfAbsent(_weekOf(entry.cookedAt), () => []).add(entry);
    }
    final weeks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return PaginationController(
      policy: const PaginationPolicy.history(),
      loader: (request) async {
        final start = request.pageIndex * request.limit;
        if (start >= weeks.length) {
          return PaginationPage(
            items: const [],
            hasMore: false,
            unitsLoaded: 0,
          );
        }
        final end = (start + request.limit).clamp(start, weeks.length);
        final selected = weeks.sublist(start, end);
        return PaginationPage(
          items: [for (final week in selected) ...grouped[week]!],
          hasMore: end < weeks.length,
          unitsLoaded: selected.length,
          nextAnchor: end < weeks.length ? weeks[end].toIso8601String() : null,
        );
      },
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('history.title'))),
      body: PaperSurface(
        child: _pagination.isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : _pagination.items.isEmpty
            ? MorphEmptyState(
                icon: Icons.history_rounded,
                title: context.strings('history.title'),
                message: context.strings('cook.completeBody'),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                itemCount:
                    _pagination.items.length + (_pagination.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _pagination.items.length) {
                    unawaited(_pagination.loadMore());
                    return const MorphSkeleton(height: 90);
                  }
                  if (_pagination.shouldLoadMore(index)) {
                    unawaited(_pagination.loadMore());
                  }
                  final entry = _pagination.items[index];
                  final recipe = widget.recipesById[entry.recipeId];
                  final week = _weekOf(entry.cookedAt);
                  final previousWeek = index == 0
                      ? null
                      : _weekOf(_pagination.items[index - 1].cookedAt);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (previousWeek != week)
                        SectionHeading(
                          title: _weekLabel(week, widget.languageCode),
                          kicker: context.strings('common.week'),
                        ),
                      if (recipe != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => widget.onOpenRecipe(recipe),
                          leading: CircleAvatar(
                            backgroundColor: context.morph.teal.withValues(
                              alpha: .16,
                            ),
                            child: const Icon(Icons.restaurant_rounded),
                          ),
                          title: Text(
                            recipe.name.resolve(widget.languageCode),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Text(
                            '${_date(entry.cookedAt, widget.languageCode)} · ${context.strings.plural('common.servingCount', entry.servings)}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

DateTime _weekOf(DateTime input) {
  final date = input.toLocal();
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _weekLabel(DateTime monday, String language) {
  final sunday = monday.add(const Duration(days: 6));
  return '${_date(monday, language)} – ${_date(sunday, language)}';
}

String _date(DateTime input, String language) {
  return DateFormat.yMMMd(language).format(input.toLocal());
}
