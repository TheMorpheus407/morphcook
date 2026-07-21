import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/localized_text.dart';
import '../models/user_data.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import '../widgets/states.dart';
import 'recipe_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  var _weeks = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppController>().ensureAllContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    final now = DateTime.now();
    final newest = app.history.isEmpty ? now : app.history.first.cookedAt;
    final pageAnchor = now.difference(newest).inDays > 49 ? newest : now;
    final cutoff = pageAnchor.subtract(Duration(days: _weeks * 7));
    final visible = app.history
        .where((item) => item.cookedAt.isAfter(cutoff))
        .take(50)
        .toList();
    final rows = _rows(visible, lang);
    return Scaffold(
      appBar: AppBar(title: Text(Copy.text('history', lang))),
      body: PaperBackground(
        child: app.history.isEmpty
            ? EmptyPageNote(
                icon: Icons.history,
                title: lang == 'de'
                    ? 'Deine gekochten Seiten erscheinen hier.'
                    : 'The pages you cook will appear here.',
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < 350 &&
                      visible.length < app.history.length &&
                      visible.length < 50) {
                    setState(() => _weeks += 7);
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(15, 8, 15, 30),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row.label != null) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(2, 19, 2, 8),
                        child: Row(
                          children: [
                            Text(
                              row.label!.toUpperCase(),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(child: DashedRule()),
                          ],
                        ),
                      );
                    }
                    final item = row.item!;
                    final recipe = app.content.recipeById(item.recipeId);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        width: 43,
                        height: 43,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: BrandColors.tealLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 20),
                      ),
                      title: Text(
                        recipe?.title.value(lang) ?? item.recipeId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        '${DateFormat('EEEE · HH:mm', lang == 'de' ? 'de_DE' : 'en_US').format(item.cookedAt)} · ${item.servings} ${Copy.text('servings', lang)}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      trailing: recipe == null
                          ? null
                          : const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: recipe == null
                          ? null
                          : () => openRecipeDetail(
                              context,
                              recipe.dishId,
                              recipe.id,
                            ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  List<_HistoryRow> _rows(List<CookingHistoryEntry> entries, String lang) {
    final result = <_HistoryRow>[];
    DateTime? previousWeek;
    for (final item in entries) {
      final date = DateTime(
        item.cookedAt.year,
        item.cookedAt.month,
        item.cookedAt.day,
      );
      final monday = date.subtract(Duration(days: date.weekday - 1));
      if (previousWeek != monday) {
        final end = monday.add(const Duration(days: 6));
        final locale = lang == 'de' ? 'de_DE' : 'en_US';
        result.add(
          _HistoryRow.label(
            '${DateFormat('d MMM', locale).format(monday)} — ${DateFormat('d MMM', locale).format(end)}',
          ),
        );
        previousWeek = monday;
      }
      result.add(_HistoryRow.item(item));
    }
    return result;
  }
}

class _HistoryRow {
  const _HistoryRow.label(this.label) : item = null;
  const _HistoryRow.item(this.item) : label = null;
  final String? label;
  final CookingHistoryEntry? item;
}
