import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../ui/design.dart';

class HelpScreen extends StatefulWidget {
  final AppState state;
  final String? initialCategory;
  const HelpScreen({super.key, required this.state, this.initialCategory});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _query = '';
  String? _category;
  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  String _text(dynamic value) => value is Map
      ? localized(localizedMap(value), widget.state.profile.lang)
      : '$value';
  String _categoryLabel(String category) {
    final labels = <String, List<String>>{
      'dietary': ['Eating your way', 'Deine Ernährung'],
      'matching': ['Your recipes', 'Deine Rezepte'],
      'recipes': ['Recipes', 'Rezepte'],
      'cooking': ['In the kitchen', 'In der Küche'],
      'shopping': ['Shopping', 'Einkaufen'],
      'planning': ['Meal planning', 'Wochenplan'],
      'privacy': ['Privacy & backups', 'Datenschutz & Backups'],
      'backup': ['Backups', 'Backups'],
      'troubleshooting': ['A little help', 'Kleine Helfer'],
      'features': ['How things work', 'So funktioniert’s'],
      'general': ['The basics', 'Die Grundlagen'],
      'accessibility': ['Accessibility', 'Barrierefreiheit'],
    };
    final value = labels[category];
    return value == null
        ? category.replaceAll('_', ' ')
        : tr(widget.state, value[0], value[1]);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final s = widget.state;
      final entries = s.repo.faqs;
      final categories = entries
          .map((e) => e['category'].toString())
          .toSet()
          .toList();
      final filtered = entries
          .where(
            (e) =>
                (_category == null || e['category'] == _category) &&
                '${_text(e['question'])} ${_text(e['answer'])}'
                    .toLowerCase()
                    .contains(_query.toLowerCase()),
          )
          .toList();
      return PaperScaffold(
        appBar: AppBar(
          title: mono(tr(s, 'THE HELP DESK', 'DIE KLEINE HILFE')),
          backgroundColor: Palette.paper,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageHeader(
                          title: tr(
                            s,
                            'a little guidance.',
                            'ein wenig Orientierung.',
                          ),
                          subtitle: tr(
                            s,
                            'A good cookbook leaves no question simmering.',
                            'Ein gutes Kochbuch lässt keine Frage offen.',
                          ),
                        ),
                        const SizedBox(height: 25),
                        TextField(
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: tr(
                              s,
                              'What would you like to know?',
                              'Was möchtest du wissen?',
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          children: [
                            ChoiceChip(
                              label: Text(tr(s, 'Everything', 'Alles')),
                              selected: _category == null,
                              onSelected: (_) =>
                                  setState(() => _category = null),
                            ),
                            for (final category in categories)
                              ChoiceChip(
                                label: Text(_categoryLabel(category)),
                                selected: _category == category,
                                onSelected: (_) =>
                                    setState(() => _category = category),
                              ),
                          ],
                        ),
                        const SizedBox(height: 19),
                        SectionLabel(
                          tr(
                            s,
                            '${filtered.length} ANSWERS, FRESHLY WRITTEN',
                            '${filtered.length} ANTWORTEN FÜR DICH',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      title: tr(
                        s,
                        'nothing on this page.',
                        'noch keine Antwort.',
                      ),
                      message: tr(
                        s,
                        'Try a shorter search, or choose another topic.',
                        'Versuche einen kürzeren Suchbegriff oder ein anderes Thema.',
                      ),
                      icon: Icons.question_answer_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final entry = filtered[i];
                        return Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Palette.line),
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: ValueKey(entry['id']),
                              tilePadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.start,
                              childrenPadding: const EdgeInsets.only(
                                bottom: 24,
                                right: 20,
                              ),
                              title: Text(
                                _text(entry['question']),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Palette.ink,
                                ),
                              ),
                              children: [
                                Text(
                                  _text(entry['answer']),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.65,
                                    color: Palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                    child: Center(
                      child: hand(
                        tr(
                          s,
                          'a little less guessing. a little more cooking.',
                          'weniger Rätsel. mehr Kochen.',
                        ),
                        color: Palette.coral,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
