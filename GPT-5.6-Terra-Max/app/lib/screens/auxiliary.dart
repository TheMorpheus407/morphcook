import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../copy.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController();
  final _ingredientSearch = TextEditingController();
  var _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _name.text = MorphCookScope.of(context).profile.name;
    _initialised = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _ingredientSearch.dispose();
    super.dispose();
  }

  void _update(Profile value) =>
      MorphCookScope.of(context).updateProfile(value);

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final profile = state.profile;
    final lang = state.lang;
    final suggestion = state.repository.ingredientIndex.search(
      _ingredientSearch.text,
      lang,
    );
    return PaperScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const Masthead(compact: true, leading: OverlayBackButton()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 7, 20, 18),
            child: Text(
              Copybook.t('settings', lang),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          _SettingsSection(
            title: Copybook.t('profile', lang),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  onEditingComplete: () =>
                      _update(profile.copyWith(name: _name.text.trim())),
                  decoration: InputDecoration(
                    labelText: Copybook.t('name', lang),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Copybook.t('language', lang),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('EN')),
                        ButtonSegment(value: 'de', label: Text('DE')),
                      ],
                      selected: {profile.lang},
                      onSelectionChanged: (values) =>
                          _update(profile.copyWith(lang: values.first)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SettingsSection(
            title: Copybook.t('avoid', lang),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children:
                      [
                            'vegan',
                            'vegetarian',
                            'dairy',
                            'gluten',
                            'nuts',
                            'halal',
                            'kosher',
                            'low-fodmap',
                            'sugar-free',
                          ]
                          .map(
                            (flag) => FilterChip(
                              label: Text(_flagLabel(flag, lang)),
                              selected: profile.avoidFlags.contains(flag),
                              onSelected: (_) {
                                final flags = {...profile.avoidFlags};
                                if (!flags.add(flag)) flags.remove(flag);
                                _update(profile.copyWith(avoidFlags: flags));
                              },
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  Copybook.t('specificAvoid', lang).toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _ingredientSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                if (profile.avoidIngredients.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profile.avoidIngredients
                        .map(
                          (id) => InputChip(
                            label: Text(
                              state.repository.ingredients[id]?.nameFor(lang) ??
                                  id,
                            ),
                            onDeleted: () {
                              final ids = {...profile.avoidIngredients}
                                ..remove(id);
                              _update(profile.copyWith(avoidIngredients: ids));
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                ...suggestion
                    .take(5)
                    .map(
                      (ingredient) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(ingredient.nameFor(lang)),
                        trailing: Icon(
                          profile.avoidIngredients.contains(ingredient.id)
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: MorphColors.coral,
                        ),
                        onTap: () {
                          final ids = {...profile.avoidIngredients};
                          if (!ids.add(ingredient.id)) {
                            ids.remove(ingredient.id);
                          }
                          _update(profile.copyWith(avoidIngredients: ids));
                        },
                      ),
                    ),
              ],
            ),
          ),
          _SettingsSection(
            title: Copybook.t('goalsQuestion', lang),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingSlider(
                  label: Copybook.t('timeBudget', lang),
                  value: profile.maxTimeMinutes.toDouble(),
                  text: '${profile.maxTimeMinutes} min',
                  min: 15,
                  max: 90,
                  divisions: 5,
                  color: MorphColors.teal,
                  onChanged: (value) =>
                      _update(profile.copyWith(maxTimeMinutes: value.round())),
                ),
                const SizedBox(height: 13),
                _SettingSlider(
                  label: Copybook.t('calorieTarget', lang),
                  value: profile.calorieTarget.toDouble(),
                  text: '${profile.calorieTarget} kcal',
                  min: 400,
                  max: 900,
                  divisions: 5,
                  color: MorphColors.coral,
                  onChanged: (value) =>
                      _update(profile.copyWith(calorieTarget: value.round())),
                ),
                const SizedBox(height: 15),
                Text(
                  Copybook.t('preferredEffort', lang).toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  children: ['easy', 'medium', 'hard']
                      .map(
                        (effort) => ChoiceChip(
                          label: Text(Copybook.t(effort, lang)),
                          selected: profile.preferredEffort == effort,
                          onSelected: (_) => _update(
                            profile.copyWith(preferredEffort: effort),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          _SettingsSection(
            title: Copybook.t('requirements', lang),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Copybook.t('halal', lang)),
                  value: profile.requiredAttributes.contains('halal'),
                  onChanged: (enabled) {
                    final attrs = {...profile.requiredAttributes};
                    if (enabled) {
                      attrs.add('halal');
                    } else {
                      attrs.remove('halal');
                    }
                    _update(profile.copyWith(requiredAttributes: attrs));
                  },
                ),
                Text(
                  Copybook.t('halalNote', lang),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: MorphColors.mutedInk),
                ),
                const SizedBox(height: 13),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Copybook.t('kosher', lang)),
                  value: profile.requiredAttributes.contains('kosher'),
                  onChanged: (enabled) {
                    final attrs = {...profile.requiredAttributes};
                    if (enabled) {
                      attrs.add('kosher');
                    } else {
                      attrs.remove('kosher');
                    }
                    _update(profile.copyWith(requiredAttributes: attrs));
                  },
                ),
                Text(
                  Copybook.t('kosherNote', lang),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: MorphColors.mutedInk),
                ),
              ],
            ),
          ),
          _SettingsSection(
            title: Copybook.t('quietControls', lang),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Copybook.t('showTags', lang)),
                  value: profile.showVariantTags,
                  onChanged: (value) =>
                      _update(profile.copyWith(showVariantTags: value)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Copybook.t('visualAlerts', lang)),
                  value: profile.visualAlertEnabled,
                  onChanged: (value) =>
                      _update(profile.copyWith(visualAlertEnabled: value)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Copybook.t('reduceMotion', lang)),
                  subtitle: Text(
                    profile.reduceMotion == null
                        ? (lang == 'de' ? 'systemstandard' : 'system default')
                        : '',
                  ),
                  value: profile.reduceMotion ?? false,
                  onChanged: (value) =>
                      _update(profile.copyWith(reduceMotion: value)),
                ),
                TextButton(
                  onPressed: () =>
                      _update(profile.copyWith(clearReduceMotion: true)),
                  child: Text(
                    lang == 'de'
                        ? 'Systemstandard verwenden'
                        : 'Use system default',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(Copybook.t('quickTap', lang)),
                  value: profile.quickNextTapEnabled,
                  onChanged: (value) =>
                      _update(profile.copyWith(quickNextTapEnabled: value)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
            child: Column(
              children: [
                _ActionCard(
                  icon: Icons.help_outline,
                  label: Copybook.t('faq', lang),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const FaqScreen())),
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.query_stats_outlined,
                  label: Copybook.t('insights', lang),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ShoppingInsightsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.history,
                  label: Copybook.t('history', lang),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CookingHistoryScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _ActionCard(
                  icon: Icons.archive_outlined,
                  label: Copybook.t('backup', lang),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BackupRestoreScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(letterSpacing: 1.1),
        ),
        const SizedBox(height: 9),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .38),
            border: Border.all(color: const Color(0xffb3a593)),
          ),
          child: child,
        ),
      ],
    ),
  );
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.text,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final double value;
  final String text;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          Text(text, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        activeColor: color,
        onChanged: onChanged,
      ),
    ],
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .42),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: MorphColors.teal),
            const SizedBox(width: 13),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleLarge),
            ),
            const Icon(Icons.arrow_forward_ios, size: 15),
          ],
        ),
      ),
    ),
  );
}

String _flagLabel(String flag, String lang) {
  const explicit = {
    'dairy': {'en': 'dairy', 'de': 'milchprodukte'},
    'nuts': {'en': 'nuts', 'de': 'nüsse'},
    'vegetarian': {'en': 'vegetarian', 'de': 'vegetarisch'},
    'low-fodmap': {'en': 'low-FODMAP', 'de': 'low-FODMAP'},
    'sugar-free': {'en': 'sugar-free', 'de': 'zuckerfrei'},
  };
  return localize(explicit[flag] ?? {'en': flag, 'de': flag}, lang);
}

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _search = TextEditingController();
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final categories =
        state.repository.faqs.map((entry) => entry.category).toSet().toList()
          ..sort();
    final needle = _search.text.toLowerCase();
    final entries = state.repository.faqs.where((entry) {
      final matchCategory = _category == null || entry.category == _category;
      final text =
          '${localize(entry.question, state.lang)} ${localize(entry.answer, state.lang)}'
              .toLowerCase();
      return matchCategory && (needle.isEmpty || text.contains(needle));
    }).toList();
    return PaperScaffold(
      body: Column(
        children: [
          const Masthead(compact: true, leading: OverlayBackButton()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                Copybook.t('faq', state.lang),
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: Copybook.t('searchHint', state.lang),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                ChoiceChip(
                  label: Text(Copybook.t('all', state.lang)),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                const SizedBox(width: 7),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => Material(
                color: Colors.white.withValues(alpha: .42),
                child: ExpansionTile(
                  title: Text(
                    localize(entries[index].question, state.lang),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(
                    entries[index].category,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      localize(entries[index].answer, state.lang),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IngredientGuideScreen extends StatelessWidget {
  const IngredientGuideScreen({super.key, required this.ingredientId});
  final String ingredientId;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final ingredient = state.repository.ingredients[ingredientId];
    if (ingredient == null) {
      return const Scaffold(
        body: Center(child: Text('Ingredient unavailable')),
      );
    }
    final lang = state.lang;
    final rows = [
      (Copybook.t('whatItIs', lang), ingredient.description),
      (Copybook.t('littleTip', lang), ingredient.usageTips),
      (Copybook.t('storage', lang), ingredient.storage),
      (Copybook.t('whereToFind', lang), ingredient.whereToFind),
    ].where((row) => row.$2.values.any((value) => value.isNotEmpty)).toList();
    return PaperScaffold(
      body: ListView(
        children: [
          const Masthead(compact: true, leading: OverlayBackButton()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Text(
              ingredient.nameFor(lang),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.$1.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    localize(row.$2, lang),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CookingHistoryScreen extends StatefulWidget {
  const CookingHistoryScreen({super.key});

  @override
  State<CookingHistoryScreen> createState() => _CookingHistoryScreenState();
}

class _CookingHistoryScreenState extends State<CookingHistoryScreen> {
  var _weeks = 7;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final cutoff = DateTime.now().subtract(Duration(days: _weeks * 7));
    final entries =
        state.history.where((entry) => entry.cookedAt.isAfter(cutoff)).toList()
          ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    final grouped = <DateTime, List<HistoryEntry>>{};
    for (final entry in entries.take(50)) {
      final day = DateTime(
        entry.cookedAt.year,
        entry.cookedAt.month,
        entry.cookedAt.day,
      );
      final monday = day.subtract(
        Duration(days: day.weekday - DateTime.monday),
      );
      grouped.putIfAbsent(monday, () => []).add(entry);
    }
    return PaperScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const Masthead(compact: true, leading: OverlayBackButton()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 7),
            child: Text(
              Copybook.t('history', state.lang),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          if (entries.isEmpty)
            EmptyNote(
              message: state.lang == 'de'
                  ? 'Wenn du ein Rezept abschließt, erscheint es hier.'
                  : 'Finish a recipe and it will leave a little note here.',
              icon: Icons.history,
            )
          else ...[
            ...grouped.entries.expand(
              (group) => [
                SectionTitle(
                  children: state.lang == 'de'
                      ? 'Woche vom ${group.key.day}.${group.key.month}.'
                      : 'week of ${group.key.month}/${group.key.day}',
                ),
                ...group.value.map((entry) {
                  final recipe = state.recipeById(entry.recipeId);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: MorphColors.teal,
                      ),
                      title: Text(
                        recipe?.titleFor(state.lang) ?? entry.recipeId,
                      ),
                      subtitle: Text(
                        '${entry.cookedAt.day}.${entry.cookedAt.month}.${entry.cookedAt.year}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  );
                }),
              ],
            ),
            if (entries.length < state.history.length && _weeks < 52)
              Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton(
                  onPressed: () => setState(() => _weeks += 7),
                  child: Text(
                    state.lang == 'de'
                        ? '7 weitere Wochen laden'
                        : 'load 7 more weeks',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class ShoppingInsightsScreen extends StatelessWidget {
  const ShoppingInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final insight = ShoppingInsights.fromEvents(state.shoppingEvents);
    final monthNames = state.lang == 'de'
        ? const [
            'Jan',
            'Feb',
            'Mär',
            'Apr',
            'Mai',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Okt',
            'Nov',
            'Dez',
          ]
        : const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
    return PaperScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const Masthead(compact: true, leading: OverlayBackButton()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 19),
            child: Text(
              Copybook.t('insights', state.lang),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          if (state.shoppingEvents.isEmpty)
            EmptyNote(
              message: Copybook.t('noData', state.lang),
              icon: Icons.insights_outlined,
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MorphColors.teal.withValues(alpha: .1),
                  border: Border.all(color: MorphColors.teal),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Copybook.t('variety', state.lang).toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${insight.varietyScore}',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: MorphColors.teal,
                      ),
                    ),
                    Text(
                      state.lang == 'de'
                          ? 'einzigartige Zutaten über deine Einkäufe'
                          : 'unique ingredients across your shopping trips',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SectionTitle(children: Copybook.t('topIngredients', state.lang)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: insight.topIngredients.map((frequency) {
                  final ingredient =
                      state.repository.ingredients[frequency.ingredientId];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      '${frequency.count}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: MorphColors.coral),
                    ),
                    title: Text(
                      ingredient?.nameFor(state.lang) ?? frequency.ingredientId,
                    ),
                  );
                }).toList(),
              ),
            ),
            SectionTitle(children: Copybook.t('seasonal', state.lang)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _MonthBars(
                values: insight.seasonalBreakdown,
                names: monthNames,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.values, required this.names});
  final Map<int, int> values;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.values.fold(
      1,
      (max, value) => value > max ? value : max,
    );
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (index) {
          final value = values[index + 1] ?? 0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (value > 0)
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  Container(
                    height: 110 * value / maxValue,
                    color: MorphColors.mustard.withValues(alpha: .75),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    names[index],
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(fontSize: 8),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    return PaperScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const Masthead(compact: true, leading: OverlayBackButton()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Text(
              Copybook.t('backup', state.lang),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              state.lang == 'de'
                  ? 'Zwei Dateien werden erzeugt: eine lesbare JSON-Datei (auf Wunsch AES-256-GCM-verschlüsselt) und eine unverschlüsselte, komprimierte .gz-Datei.'
                  : 'Export creates two files: readable JSON (optionally AES-256-GCM encrypted) and an unencrypted compressed .gz file.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkButton(
              expanded: true,
              label: Copybook.t('export', state.lang),
              icon: Icons.ios_share,
              onPressed: () => _export(context),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: MorphColors.ink,
              ),
              onPressed: () => _restore(context),
              icon: const Icon(Icons.file_open_outlined),
              label: Text(Copybook.t('restore', state.lang)),
            ),
          ),
          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              state.lang == 'de'
                  ? 'Beim Import bleibt der mitgelieferte Rezeptbestand unangetastet.'
                  : 'Import never changes the bundled recipe corpus.',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final state = MorphCookScope.of(context);
    final password = await _askPassword(
      context,
      title: Copybook.t('export', state.lang),
    );
    if (password == null || !context.mounted) return;
    try {
      final files = await BackupService.writeBackup(
        state.exportData(),
        password: password.isEmpty ? null : password,
      );
      await Share.shareXFiles(
        [XFile(files.jsonFile.path), XFile(files.gzipFile.path)],
        subject: 'MorphCook backup',
        text: 'MorphCook backup — JSON and compressed GZip.',
      );
      if (context.mounted) {
        _notice(
          context,
          state.lang == 'de'
              ? 'Backup bereit zum Teilen.'
              : 'Backup ready to share.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _notice(
          context,
          state.lang == 'de'
              ? 'Backup konnte nicht erstellt werden.'
              : 'Could not create backup.',
        );
      }
    }
  }

  Future<void> _restore(BuildContext context) async {
    final state = MorphCookScope.of(context);
    final selection = await FilePicker.platform.pickFiles(
      withData: true,
      allowedExtensions: const ['json', 'gz'],
      type: FileType.custom,
    );
    if (selection == null || selection.files.isEmpty || !context.mounted) {
      return;
    }
    final picked = selection.files.single;
    final bytes =
        picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null || !context.mounted) return;
    Map<String, dynamic>? payload;
    try {
      payload = await BackupService.decode(bytes);
    } on DecryptionException catch (error) {
      if (!error.needsPassword || !context.mounted) {
        if (context.mounted) _notice(context, error.message);
        return;
      }
      final password = await _askPassword(
        context,
        title: Copybook.t('passwordOptional', state.lang),
        required: true,
      );
      if (password == null || !context.mounted) return;
      try {
        payload = await BackupService.decode(bytes, password: password);
      } on DecryptionException catch (retryError) {
        if (context.mounted) _notice(context, retryError.message);
        return;
      }
    }
    if (!context.mounted) return;
    final merge = await _askRestoreMode(context, state.lang);
    if (merge == null || !context.mounted) return;
    await state.restore(payload, merge: merge);
    if (context.mounted) {
      _notice(
        context,
        state.lang == 'de' ? 'Backup wiederhergestellt.' : 'Backup restored.',
      );
    }
  }

  Future<String?> _askPassword(
    BuildContext context, {
    required String title,
    bool required = false,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: required
                ? 'Password'
                : Copybook.t(
                    'passwordOptional',
                    MorphCookScope.of(context).lang,
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(Copybook.t('cancel', MorphCookScope.of(context).lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(
              Copybook.t('continue', MorphCookScope.of(context).lang),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<bool?> _askRestoreMode(BuildContext context, String lang) =>
      showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(Copybook.t('restore', lang)),
          content: Text(
            lang == 'de'
                ? 'Wie sollen die Daten übernommen werden?'
                : 'How should these data be brought in?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(Copybook.t('cancel', lang)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(Copybook.t('replace', lang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(Copybook.t('merge', lang)),
            ),
          ],
        ),
      );

  void _notice(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
