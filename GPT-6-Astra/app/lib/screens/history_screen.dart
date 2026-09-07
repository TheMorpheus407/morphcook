import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/design.dart';

class HistoryScreen extends StatefulWidget {
  final AppState state;
  final void Function(Recipe)? onOpenRecipe;
  const HistoryScreen({super.key, required this.state, this.onOpenRecipe});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _weeks = 7;
  bool _loading = false;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_prefetch);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime get _cutoff {
    final monday = mondayOfWeek(DateTime.now());
    return DateTime(monday.year, monday.month, monday.day - 7 * (_weeks - 1));
  }

  bool get _hasMore => widget.state.history.any(
    (e) =>
        (DateTime.tryParse(e['cooked_at']?.toString() ?? '') ?? DateTime.now())
            .isBefore(_cutoff),
  );
  void _prefetch() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 450) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    // A frame of loading keeps large local histories responsive.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _weeks += 7;
        _loading = false;
      });
    }
  }

  Recipe? _recipe(String? id) {
    for (final r in widget.state.repo.recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final s = widget.state;
      final events =
          s.history
              .where(
                (e) =>
                    !(DateTime.tryParse(e['cooked_at']?.toString() ?? '') ??
                            DateTime.now())
                        .isBefore(_cutoff),
              )
              .toList()
            ..sort(
              (a, b) => (b['cooked_at']?.toString() ?? '').compareTo(
                a['cooked_at']?.toString() ?? '',
              ),
            );
      final rows = <Object>[];
      String? lastWeek;
      for (final event in events) {
        final date =
            DateTime.tryParse(
              event['cooked_at']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();
        final key = weekKey(date);
        if (key != lastWeek) {
          rows.add(mondayOfWeek(date));
          lastWeek = key;
        }
        rows.add(event);
      }
      return PaperScaffold(
        appBar: AppBar(
          title: mono(tr(s, 'FROM YOUR KITCHEN', 'AUS DEINER KÜCHE')),
          backgroundColor: Palette.paper,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageHeader(
                          title: tr(
                            s,
                            'meals & memories.',
                            'Mahlzeiten & Erinnerungen.',
                          ),
                          subtitle: tr(
                            s,
                            'A little record of the things you’ve made.',
                            'Eine kleine Sammlung von dem, was du gekocht hast.',
                          ),
                        ),
                        mono(
                          tr(
                            s,
                            '${s.history.length} MEALS COOKED',
                            '${s.history.length} MAL GEKOCHT',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (s.history.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: tr(
                        s,
                        'the first page awaits.',
                        'die erste Seite wartet.',
                      ),
                      message: tr(
                        s,
                        'Finish a recipe in cook mode and it will find a home here.',
                        'Schließe ein Rezept im Kochmodus ab. Hier findet es seinen Platz.',
                      ),
                      icon: Icons.history,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        if (row is DateTime) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: SectionLabel(
                              tr(
                                s,
                                'WEEK OF ${row.day}.${row.month}.${row.year}',
                                'WOCHE VOM ${row.day}.${row.month}.${row.year}',
                              ),
                            ),
                          );
                        }
                        final event = row as Map<String, dynamic>;
                        final recipe = _recipe(event['recipe_id']?.toString());
                        final date = DateTime.tryParse(
                          event['cooked_at']?.toString() ?? '',
                        )?.toLocal();
                        final title = recipe == null
                            ? tr(s, 'A meal well made', 'Eine gute Mahlzeit')
                            : localized(recipe.title, s.profile.lang);
                        return Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Palette.line),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            leading: Container(
                              width: 45,
                              height: 52,
                              color: Palette.sage,
                              alignment: Alignment.center,
                              child: mono(
                                date == null
                                    ? '—'
                                    : '${date.day.toString().padLeft(2, '0')}\n${date.month.toString().padLeft(2, '0')}',
                                color: Palette.ink,
                              ),
                            ),
                            title: Text(title),
                            subtitle: Text(
                              recipe == null
                                  ? tr(
                                      s,
                                      'Saved in your cooking history',
                                      'In deinem Kochverlauf gespeichert',
                                    )
                                  : '${recipe.timeMinutes} min · ${recipe.calories} kcal',
                            ),
                            trailing:
                                recipe != null && widget.onOpenRecipe != null
                                ? const Icon(Icons.arrow_outward, size: 18)
                                : const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Palette.muted,
                                  ),
                            onTap: recipe == null || widget.onOpenRecipe == null
                                ? null
                                : () => widget.onOpenRecipe!(recipe),
                          ),
                        );
                      },
                    ),
                  ),
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: TextButton(
                        onPressed: _loadMore,
                        child: Text(
                          tr(
                            s,
                            'Turn back seven more weeks',
                            'Sieben weitere Wochen zurückblättern',
                          ),
                        ),
                      ),
                    ),
                  )
                else if (s.history.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(
                        child: hand(
                          tr(
                            s,
                            'and that’s where the story began.',
                            'und hier begann die Geschichte.',
                          ),
                          color: Palette.coral,
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
