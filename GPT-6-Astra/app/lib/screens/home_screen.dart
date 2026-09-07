import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/matching.dart';
import '../ui/design.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppState state;
  final void Function(Recipe) onOpen;
  final VoidCallback onDiscover;
  const HomeScreen({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onDiscover,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String mood = 'all';
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final lang = s.profile.lang;
    final recipes =
        s.repo.dishes.map((d) => s.recommended(d)).whereType<Recipe>().toList()
          ..sort(
            (a, b) => rankRecipe(
              b,
              s.profile,
              history: s.history,
            ).compareTo(rankRecipe(a, s.profile, history: s.history)),
          );
    final featured =
        recipes.where((r) => r.dishId == 'doener').firstOrNull ??
        recipes.firstOrNull;
    final filtered = recipes
        .where(
          (r) =>
              mood == 'all' ||
              (mood == 'quick' && r.timeMinutes <= 30) ||
              (mood == 'slow' && r.timeMinutes > 30) ||
              (mood == 'plant' &&
                  (r.diet == 'vegan' || r.diet == 'vegetarian')),
        )
        .toList();
    final date = DateFormat(
      'EEEE, d MMMM',
      lang,
    ).format(DateTime.now()).toUpperCase();
    final name = s.profile.name.trim().isEmpty
        ? tr(s, 'friend', 'du')
        : s.profile.name.trim();
    return LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 760;
        return SingleChildScrollView(
          key: const PageStorageKey('home'),
          padding: EdgeInsets.symmetric(horizontal: wide ? 44 : 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: mono(date, size: 8)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: mono(
                          tr(
                            s,
                            'VOL. 01 · MADE FOR YOU',
                            'AUSGABE 01 · FÜR DICH',
                          ),
                          size: 8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(child: display('morphcook', size: wide ? 90 : 64)),
                  const SizedBox(height: 9),
                  Center(
                    child: mono(
                      tr(
                        s,
                        'GOOD FOOD. YOUR WAY. EVERY DAY.',
                        'GUTES ESSEN. AUF DEINE ART. JEDEN TAG.',
                      ),
                      size: wide ? 10 : 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(height: 3, color: Palette.ink),
                  const SizedBox(height: 4),
                  const Divider(color: Palette.ink),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              display(
                                tr(s, 'hello, $name.', 'hallo, $name.'),
                                size: wide ? 34 : 30,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                tr(
                                  s,
                                  'Come as you are. Cook what you love.',
                                  'Komm, wie du bist. Koch, was du liebst.',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (wide)
                          Transform.rotate(
                            angle: -.06,
                            child: hand(
                              tr(
                                s,
                                'your apron is waiting',
                                'deine Schürze wartet',
                              ),
                              size: 27,
                              color: Palette.coral,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (featured != null)
                    _featured(s, featured, wide)
                  else
                    EmptyState(
                      title: tr(s, 'a fresh start', 'ein neuer Anfang'),
                      message: tr(
                        s,
                        'No recipes fit these preferences yet. Adjust your time or calorie range in Settings.',
                        'Noch passt kein Rezept. Ändere Zeit oder Kalorienbereich in den Einstellungen.',
                      ),
                    ),
                  const SizedBox(height: 27),
                  Row(
                    children: [
                      Expanded(
                        child: display(
                          tr(s, 'what sounds good?', 'worauf hast du Lust?'),
                          size: 29,
                        ),
                      ),
                      if (wide)
                        hand(
                          tr(
                            s,
                            'follow your appetite',
                            'hör auf deinen Appetit',
                          ),
                          size: 23,
                          color: Palette.muted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _moodChip(
                        'all',
                        tr(s, 'a bit of everything', 'von allem etwas'),
                        Icons.restaurant_outlined,
                      ),
                      _moodChip(
                        'quick',
                        tr(s, 'quick & lovely', 'schnell & fein'),
                        Icons.schedule,
                      ),
                      _moodChip(
                        'plant',
                        tr(s, 'plant-powered', 'Pflanzenliebe'),
                        Icons.eco_outlined,
                      ),
                      _moodChip(
                        'slow',
                        tr(s, 'slow afternoons', 'ruhige Nachmittage'),
                        Icons.wb_sunny_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SectionLabel(
                    tr(
                      s,
                      'little everyday favourites',
                      'kleine Alltagslieblinge',
                    ),
                  ),
                  if (filtered.isEmpty)
                    EmptyState(
                      title: tr(
                        s,
                        'a different kind of day',
                        'heute mal anders',
                      ),
                      message: tr(
                        s,
                        'Try another mood. There is something good waiting.',
                        'Versuch eine andere Stimmung. Etwas Gutes wartet auf dich.',
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (c, b) {
                        final cols = wide ? 4 : 2;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 23,
                          children: List.generate(
                            filtered.length.clamp(0, 8),
                            (i) => SizedBox(
                              width: (b.maxWidth - (cols - 1) * 16) / cols,
                              child: RecipeCard(
                                state: s,
                                recipe: filtered[i],
                                onTap: () => widget.onOpen(filtered[i]),
                                index: i,
                                compact: !wide,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: widget.onDiscover,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr(
                              s,
                              'Explore the whole kitchen',
                              'Die ganze Küche entdecken',
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward, size: 17),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _kitchenNote(s, wide),
                  const SizedBox(height: 30),
                  const DashedRule(),
                  const SizedBox(height: 20),
                  Center(
                    child: hand(
                      tr(
                        s,
                        'a full table. a happy heart.',
                        'ein voller Tisch. ein glückliches Herz.',
                      ),
                      size: 26,
                      color: Palette.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: mono(
                      tr(s, 'YOURS, ALWAYS.  ♡', 'IMMER DEINS.  ♡'),
                      size: 8,
                    ),
                  ),
                  const SizedBox(height: 34),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _moodChip(String id, String label, IconData icon) => ChoiceChip(
    showCheckmark: false,
    selected: mood == id,
    onSelected: (_) => setState(() => mood = id),
    avatar: Icon(
      icon,
      size: 15,
      color: mood == id ? Palette.white : Palette.ink,
    ),
    label: Text(
      label,
      style: TextStyle(color: mood == id ? Palette.white : Palette.ink),
    ),
  );
  Widget _featured(AppState s, Recipe recipe, bool wide) {
    final dish = s.repo.dishById(recipe.dishId)!;
    final copy = Padding(
      padding: EdgeInsets.all(wide ? 32 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Palette.coral,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              mono(
                tr(s, 'THE RECIPE OF THE DAY', 'DAS REZEPT DES TAGES'),
                size: 9,
                color: Palette.ink,
              ),
            ],
          ),
          const SizedBox(height: 20),
          display(
            localized(recipe.title, s.profile.lang).toLowerCase(),
            size: wide ? 46 : 36,
          ),
          const SizedBox(height: 14),
          Text(
            localized(recipe.description, s.profile.lang),
            style: const TextStyle(
              fontSize: 11,
              height: 1.9,
              color: Palette.muted,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              mono('${recipe.timeMinutes} MIN', size: 9, color: Palette.ink),
              mono('${recipe.calories} KCAL', size: 9, color: Palette.ink),
              if (s.profile.showVariantTags)
                mono(
                  dietLabel(s, recipe.diet).toUpperCase(),
                  size: 9,
                  color: Palette.ink,
                ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: tr(s, 'Let’s make this', 'Das kochen wir'),
            onPressed: () => widget.onOpen(recipe),
            icon: Icons.arrow_forward,
          ),
        ],
      ),
    );
    final art = Padding(
      padding: EdgeInsets.all(wide ? 18 : 12),
      child: Transform.rotate(
        angle: s.profile.reduceMotion == true ? 0 : .018,
        child: Container(
          color: Palette.white,
          padding: const EdgeInsets.fromLTRB(9, 9, 9, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  StripeArt(
                    color: stripeColor(dish.color),
                    height: wide ? 292 : 190,
                    label: localized(dish.name, s.profile.lang).toLowerCase(),
                  ),
                  Positioned(
                    top: 13,
                    left: 14,
                    child: Transform.rotate(
                      angle: -.1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        color: Palette.butter,
                        child: hand(
                          tr(
                            s,
                            'made with a little love',
                            'mit einer Prise Liebe',
                          ),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              hand(localized(dish.caption, s.profile.lang), size: 23),
            ],
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9EADF),
        border: Border.all(color: Palette.line),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(flex: 5, child: copy),
                Expanded(flex: 6, child: art),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [art, copy],
            ),
    );
  }

  Widget _kitchenNote(AppState s, bool wide) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(border: Border.all(color: Palette.line)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.auto_stories_outlined, size: 27, color: Palette.muted),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              hand(
                tr(s, 'a note from the kitchen', 'eine Notiz aus der Küche'),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  s,
                  'Different ways of eating. The same love of food. Every recipe here has a place at your table.',
                  'Verschiedene Ernährungsweisen. Dieselbe Liebe zum Essen. Jedes Rezept hat einen Platz an deinem Tisch.',
                ),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.9,
                  color: Palette.muted,
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => HelpScreen(state: s)),
                ),
                child: Text(
                  tr(
                    s,
                    'Get to know your cookbook ↗',
                    'Lerne dein Kochbuch kennen ↗',
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
