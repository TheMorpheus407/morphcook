import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/matching.dart';
import '../core/backup.dart';
import '../ui/design.dart';
import 'help_screen.dart';
import 'insights_screen.dart';
import 'history_screen.dart';
import 'detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppState state;
  final bool onboarding;
  const ProfileScreen({
    super.key,
    required this.state,
    this.onboarding = false,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Profile draft;
  late TextEditingController name;
  final ingredientQuery = TextEditingController();
  int step = 0;
  bool busy = false;
  bool allFlags = false;
  @override
  void initState() {
    super.initState();
    draft = widget.state.profile.copy();
    name = TextEditingController(text: draft.name);
  }

  @override
  void dispose() {
    name.dispose();
    ingredientQuery.dispose();
    super.dispose();
  }

  String t(String en, String de) =>
      translateUi(widget.state, draft.lang, en, de);
  void change(VoidCallback update) {
    setState(update);
    if (!widget.onboarding) {
      draft.name = name.text;
      widget.state.updateProfile(draft);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.onboarding ? _onboarding() : _settings();
  Widget _onboarding() {
    final titles = [
      t('a seat at the table.', 'ein Platz am Tisch.'),
      t('hello, you.', 'hallo, du.'),
      t('your table, your rules.', 'dein Tisch, deine Regeln.'),
      t('a little room for you.', 'ein bisschen Raum für dich.'),
      t('this kitchen is yours.', 'diese Küche gehört dir.'),
    ];
    return PaperScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    display('morphcook', size: 30),
                    mono('${step + 1} / 5', size: 10),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: Row(
                  children: List.generate(
                    5,
                    (i) => Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.only(right: 5),
                        color: i <= step ? Palette.ink : Palette.line,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      display(titles[step], size: 43),
                      const SizedBox(height: 16),
                      Text(
                        [
                          t(
                            'Good food belongs to everyone. Let’s make a cookbook that feels like home.',
                            'Gutes Essen ist für alle da. Machen wir ein Kochbuch, das sich wie Zuhause anfühlt.',
                          ),
                          t(
                            'A cookbook with your name on it. Just like the well-loved one on the kitchen shelf.',
                            'Ein Kochbuch mit deinem Namen. Wie das geliebte Exemplar im Küchenregal.',
                          ),
                          t(
                            'Every way of eating deserves something wonderful. Tell us what belongs in your kitchen.',
                            'Jede Ernährungsweise verdient etwas Wunderbares. Was gehört in deine Küche?',
                          ),
                          t(
                            'For busy Tuesdays and unhurried Sundays. Set the rhythm that feels right.',
                            'Für volle Dienstage und gemütliche Sonntage. Finde deinen eigenen Rhythmus.',
                          ),
                          t(
                            'Your favourites, your little rituals, your next good meal. Make yourself at home.',
                            'Deine Lieblinge, deine kleinen Rituale, dein nächstes gutes Essen. Fühl dich Zuhause.',
                          ),
                        ][step],
                        style: const TextStyle(
                          color: Palette.muted,
                          fontSize: 12,
                          height: 1.9,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (step == 0) ...[
                        Transform.rotate(
                          angle: -.018,
                          child: Container(
                            color: Palette.white,
                            padding: const EdgeInsets.fromLTRB(9, 9, 9, 18),
                            child: Column(
                              children: [
                                StripeArt(
                                  height: 190,
                                  color: Palette.ink,
                                  label: t(
                                    'good food & good company',
                                    'gutes Essen & gute Gesellschaft',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                hand(
                                  t(
                                    'there’s always room for one more.',
                                    'ein Platz ist immer noch frei.',
                                  ),
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SectionLabel(
                          t('First, your language', 'Zuerst deine Sprache'),
                        ),
                        _language(),
                      ] else if (step == 1) ...[
                        const SizedBox(height: 15),
                        TextField(
                          controller: name,
                          maxLength: 40,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: t('Your first name', 'Dein Vorname'),
                            hintText: t('e.g. Jamie', 'z. B. Alex'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        hand(
                          t(
                            'only your kitchen needs to know.',
                            'das bleibt in deiner Küche.',
                          ),
                          color: Palette.coral,
                        ),
                        const SizedBox(height: 25),
                        Text(
                          t(
                            'Everything stays on your device. No accounts, no tracking, just a little everyday magic.',
                            'Alles bleibt auf deinem Gerät. Keine Konten, kein Tracking, nur ein bisschen Alltagszauber.',
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Palette.muted,
                          ),
                        ),
                      ] else if (step == 2)
                        _diet()
                      else if (step == 3)
                        _targets()
                      else
                        _confirmation(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
                child: Row(
                  children: [
                    if (step > 0) ...[
                      IconButton(
                        tooltip: t('Back', 'Zurück'),
                        onPressed: () => setState(() => step--),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: PrimaryButton(
                        label: step == 4
                            ? t(
                                'Welcome to your kitchen',
                                'Willkommen in deiner Küche',
                              )
                            : t(
                                'Make yourself at home',
                                'Mach es dir gemütlich',
                              ),
                        icon: Icons.arrow_forward,
                        onPressed: () {
                          if (step < 4) {
                            setState(() => step++);
                            draft.name = name.text.trim();
                            widget.state.updateProfile(draft);
                          } else {
                            draft.name = name.text.trim();
                            draft.onboarded = true;
                            widget.state.updateProfile(draft);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _language() => LayoutBuilder(
    builder: (context, bounds) {
      final languages = languageNames(widget.state).entries.toList();
      final columns = bounds.maxWidth > 480 ? 3 : 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final language in languages)
            SizedBox(
              width: (bounds.maxWidth - (columns - 1) * 10) / columns,
              child: OutlinedButton(
                onPressed: () => change(() => draft.lang = language.key),
                style: OutlinedButton.styleFrom(
                  backgroundColor: draft.lang == language.key
                      ? Palette.ink
                      : Colors.transparent,
                  foregroundColor: draft.lang == language.key
                      ? Palette.white
                      : Palette.ink,
                  minimumSize: const Size(0, 56),
                ),
                child: Text(language.value),
              ),
            ),
        ],
      );
    },
  );
  Widget _diet() {
    final s = widget.state;
    final compounds = Map<String, dynamic>.from(
      s.repo.ontology['compounds'] as Map? ?? {},
    );
    final mainDiets = ['vegan', 'vegetarian', 'pescatarian'];
    final selected =
        mainDiets.where(draft.avoidFlags.contains).firstOrNull ?? 'classic';
    final flags = (s.repo.ontology['flags'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final common = [
      'dairy',
      'gluten',
      'egg',
      'peanuts',
      'tree-nuts',
      'soy',
      'shellfish',
      'sesame',
      'mustard',
      'celery',
      'fish',
      'molluscs',
      'lupin',
      'sulphites',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(t('How you like to eat', 'So isst du gern')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in ['classic', ...mainDiets])
              ChoiceChip(
                showCheckmark: false,
                selected: selected == id,
                label: Text(
                  {
                        'classic': t(
                          'a little of everything',
                          'ein bisschen von allem',
                        ),
                        'vegetarian': t('vegetarian', 'vegetarisch'),
                        'pescatarian': t('pescatarian', 'pescetarisch'),
                        'vegan': 'vegan',
                      }[id] ??
                      localized(
                        localizedMap(
                          (s.repo.ontology['compound_labels'] as Map?)?[id] ??
                              {'en': id},
                        ),
                        draft.lang,
                      ),
                  style: TextStyle(
                    color: selected == id ? Palette.white : Palette.ink,
                  ),
                ),
                onSelected: (_) => change(() {
                  draft.avoidFlags.removeAll(mainDiets);
                  if (id != 'classic') {
                    draft.avoidFlags.add(id);
                  }
                }),
              ),
          ],
        ),
        SectionLabel(
          t(
            'Allergies & things to leave out',
            'Allergien & was draußen bleibt',
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id
                in allFlags ? flags.map((e) => e['id'].toString()) : common)
              _avoidChip(id, _flagName(flags, id)),
          ],
        ),
        TextButton(
          onPressed: () => setState(() => allFlags = !allFlags),
          child: Text(
            allFlags
                ? t('Show common allergens', 'Häufige Allergene anzeigen')
                : t('All ingredient classes +', 'Alle Zutatenklassen +'),
          ),
        ),
        SectionLabel(t('A few more preferences', 'Noch ein paar Wünsche')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in compounds.keys.where(
              (id) =>
                  !mainDiets.contains(id) &&
                  !flags.any((flag) => flag['id'] == id),
            ))
              _avoidChip(
                id,
                {
                  'halal': t(
                    'halal-compatible ingredients',
                    'halal-kompatible Zutaten',
                  ),
                  'kosher': t(
                    'kosher-compatible ingredients',
                    'koscher-kompatible Zutaten',
                  ),
                  'low-fodmap': 'low FODMAP',
                  'sugar-free': t('no added sugar', 'ohne zugesetzten Zucker'),
                  'lactose-free': t('lactose-free', 'laktosefrei'),
                }[id]!,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'Halal- and kosher-compatible ingredients describe the recipe. Certification depends on sourcing and preparation; check your ingredients.',
            'Halal- und koscher-kompatible Zutaten beschreiben das Rezept. Zertifizierung hängt von Einkauf und Zubereitung ab; prüfe deine Zutaten.',
          ),
          style: const TextStyle(
            fontSize: 9,
            color: Palette.muted,
            height: 1.8,
          ),
        ),
        SectionLabel(t('Anything else?', 'Sonst noch etwas?')),
        Text(
          t(
            'Skip a specific ingredient or a whole family. Choosing a family also leaves out everything within it.',
            'Lass eine einzelne Zutat oder eine ganze Familie weg. Eine Familie schließt alle untergeordneten Zutaten aus.',
          ),
          style: const TextStyle(fontSize: 10, color: Palette.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ingredientQuery,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 20),
            hintText: t(
              'Apples, cilantro, bell peppers…',
              'Äpfel, Koriander, Paprika…',
            ),
          ),
        ),
        if (ingredientQuery.text.trim().isNotEmpty)
          ...s.repo.ingredients
              .where(
                (i) =>
                    localized(i.name, draft.lang).toLowerCase().contains(
                      ingredientQuery.text.toLowerCase().trim(),
                    ) &&
                    !draft.avoidIngredients.contains(i.id),
              )
              .take(8)
              .map(
                (i) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    localized(i.name, draft.lang),
                    style: const TextStyle(fontSize: 11),
                  ),
                  subtitle: i.parentId == null
                      ? Text(
                          t('Ingredient family', 'Zutatenfamilie'),
                          style: const TextStyle(fontSize: 9),
                        )
                      : null,
                  trailing: const Icon(Icons.add, size: 18),
                  onTap: () => change(() {
                    draft.avoidIngredients.add(i.id);
                    ingredientQuery.clear();
                  }),
                ),
              ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: draft.avoidIngredients
              .map(
                (id) => InputChip(
                  label: Text(
                    localized(
                      s.repo.ingredientById(id)?.name ?? {'en': id},
                      draft.lang,
                    ),
                  ),
                  onDeleted: () =>
                      change(() => draft.avoidIngredients.remove(id)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => HelpScreen(state: s))),
          icon: const Icon(Icons.help_outline, size: 16),
          label: Text(
            t(
              'How dietary matching works',
              'So funktioniert die Rezeptauswahl',
            ),
          ),
        ),
      ],
    );
  }

  String _flagName(List<Map> flags, String id) {
    final label = flags.where((f) => f['id'] == id).firstOrNull?['name'];
    if (label != null) return localized(localizedMap(label), draft.lang);
    return {
          'vegan': 'vegan',
          'vegetarian': t('vegetarian', 'vegetarisch'),
          'pescatarian': t('pescatarian', 'pescetarisch'),
          'halal': t('halal-compatible', 'halal-kompatibel'),
          'kosher': t('kosher-compatible', 'koscher-kompatibel'),
          'low-fodmap': 'low FODMAP',
          'sugar-free': t('no added sugar', 'ohne zugesetzten Zucker'),
          'lactose-free': t('lactose-free', 'laktosefrei'),
        }[id] ??
        id;
  }

  Widget _avoidChip(String id, String label) => FilterChip(
    selected: draft.avoidFlags.contains(id),
    selectedColor: Palette.sage,
    label: Text(label),
    onSelected: (yes) => change(() {
      if (yes) {
        draft.avoidFlags.add(id);
        if (id == 'halal' || id == 'kosher') {
          draft.requiredAttributes.add(id);
        }
      } else {
        draft.avoidFlags.remove(id);
        draft.requiredAttributes.remove(id);
      }
    }),
  );
  Widget _targets() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionLabel(t('Your everyday pace', 'Dein Alltagstempo')),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(t('Time in the kitchen', 'Zeit in der Küche'))),
          const SizedBox(width: 12),
          hand('${draft.maxTimeMinutes} min', size: 30, color: Palette.coral),
        ],
      ),
      Slider(
        value: draft.maxTimeMinutes.toDouble().clamp(15, 120),
        min: 15,
        max: 120,
        divisions: 7,
        label: '${draft.maxTimeMinutes} min',
        onChanged: (v) => change(() => draft.maxTimeMinutes = v.round()),
      ),
      Text(
        t(
          'Recipes stay within this time budget. Change it any time.',
          'Rezepte bleiben in diesem Zeitrahmen. Du kannst ihn jederzeit ändern.',
        ),
        style: const TextStyle(fontSize: 10, color: Palette.muted),
      ),
      const SizedBox(height: 20),
      SectionLabel(t('A little energy', 'Ein bisschen Energie')),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              t('Per-meal calorie target', 'Kalorienziel pro Mahlzeit'),
            ),
          ),
          const SizedBox(width: 12),
          hand('${draft.calorieTarget} kcal', size: 28, color: Palette.coral),
        ],
      ),
      Slider(
        value: draft.calorieTarget.toDouble().clamp(200, 1200),
        min: 200,
        max: 1200,
        divisions: 20,
        label: '${draft.calorieTarget} kcal',
        onChanged: (v) => change(() => draft.calorieTarget = v.round()),
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              t('Your comfortable range', 'Dein Wohlfühlbereich'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
          DropdownButton<int>(
            value: [100, 150, 200, 300, 400].contains(draft.calorieTolerance)
                ? draft.calorieTolerance
                : 300,
            items: [100, 150, 200, 300, 400]
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      '± $v kcal',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => change(() => draft.calorieTolerance = v!),
          ),
        ],
      ),
      Text(
        t(
          'Only recipes between ${((draft.calorieTarget - draft.calorieTolerance).clamp(0, 2000))} and ${draft.calorieTarget + draft.calorieTolerance} kcal appear. Explore beyond this range on any dish page.',
          'Es erscheinen nur Rezepte zwischen ${((draft.calorieTarget - draft.calorieTolerance).clamp(0, 2000))} und ${draft.calorieTarget + draft.calorieTolerance} kcal. Auf jeder Gerichtseite kannst du darüber hinaus stöbern.',
        ),
        style: const TextStyle(fontSize: 10, color: Palette.muted),
      ),
      const SizedBox(height: 20),
      SectionLabel(t('Most days, I feel like…', 'Meistens habe ich Lust auf…')),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in [
            ('easy', t('something easy', 'etwas Einfaches')),
            ('medium', t('a little adventure', 'ein kleines Abenteuer')),
            ('hard', t('a kitchen project', 'ein Küchenprojekt')),
          ])
            ChoiceChip(
              showCheckmark: false,
              selected: draft.preferredEffort == item.$1,
              label: Text(
                item.$2,
                style: TextStyle(
                  color: draft.preferredEffort == item.$1
                      ? Palette.white
                      : Palette.ink,
                ),
              ),
              onSelected: (_) => change(() => draft.preferredEffort = item.$1),
            ),
        ],
      ),
    ],
  );
  Widget _confirmation() {
    final s = widget.state;
    final count = s.repo.recipes
        .where(
          (r) => visible(
            r,
            draft,
            ingredients: s.repo.ingredients,
            ontology: s.repo.ontology,
          ),
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StripeArt(
          height: 160,
          color: const Color(0xFF778775),
          label: t(
            'pull up a chair, ${name.text.trim().isEmpty ? 'friend' : name.text.trim()}',
            'nimm Platz, ${name.text.trim().isEmpty ? 'du' : name.text.trim()}',
          ),
        ),
        const SizedBox(height: 22),
        SectionLabel(t('A cookbook that fits', 'Ein Kochbuch, das passt')),
        Text(
          t(
            '$count recipes are ready for your table. More can be discovered as you browse.',
            '$count Rezepte sind bereit für deinen Tisch. Beim Stöbern gibt es mehr zu entdecken.',
          ),
        ),
        const SizedBox(height: 16),
        mono(
          '${draft.maxTimeMinutes} MIN · ${draft.calorieTarget} KCAL ± ${draft.calorieTolerance}',
          size: 10,
          color: Palette.ink,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            ...draft.avoidFlags.map(
              (f) => Chip(
                label: Text(
                  _flagName(
                    (s.repo.ontology['flags'] as List? ?? [])
                        .whereType<Map>()
                        .toList(),
                    f,
                  ),
                ),
              ),
            ),
            ...draft.avoidIngredients.map(
              (f) => Chip(
                label: Text(
                  localized(
                    s.repo.ingredientById(f)?.name ?? {'en': f},
                    draft.lang,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        hand(
          t('no perfect cooks required. ♡', 'perfekte Köche nicht nötig. ♡'),
          size: 29,
          color: Palette.coral,
        ),
      ],
    );
  }

  Widget _settings() {
    final s = widget.state;
    return PaperScaffold(
      appBar: AppBar(
        title: Text(t('your little kitchen', 'deine kleine Küche')),
      ),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: t('make it your own.', 'ganz auf deine Art.'),
                    subtitle: t(
                      'A few preferences. A kitchen that feels like you. Changes save automatically.',
                      'Ein paar Wünsche. Eine Küche wie für dich gemacht. Änderungen werden automatisch gespeichert.',
                    ),
                  ),
                  SectionLabel(
                    t(
                      'The person behind the apron',
                      'Der Mensch hinter der Schürze',
                    ),
                  ),
                  TextField(
                    controller: name,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => change(() => draft.name = name.text),
                    decoration: InputDecoration(
                      labelText: t('Your name', 'Dein Name'),
                    ),
                  ),
                  _language(),
                  const SizedBox(height: 16),
                  _diet(),
                  _targets(),
                  SectionLabel(t('Little comforts', 'Kleine Annehmlichkeiten')),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: draft.showVariantTags,
                    title: Text(
                      t('Recipe labels', 'Rezeptkennzeichnungen'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      t(
                        'Show dietary and effort labels on recipe cards.',
                        'Ernährung und Aufwand auf Rezeptkarten anzeigen.',
                      ),
                      style: const TextStyle(fontSize: 10),
                    ),
                    onChanged: (v) => change(() => draft.showVariantTags = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: draft.visualAlertEnabled,
                    title: Text(
                      t('Visual timer alerts', 'Sichtbare Timer-Hinweise'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      t(
                        'A gentle color signal when a cooking timer finishes.',
                        'Ein sanftes Farbsignal, wenn ein Kochtimer endet.',
                      ),
                      style: const TextStyle(fontSize: 10),
                    ),
                    onChanged: (v) =>
                        change(() => draft.visualAlertEnabled = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: draft.quickNextTapEnabled,
                    title: Text(
                      t('One-handed cooking', 'Mit einer Hand kochen'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      t(
                        'Tap a cooking step to move to the next one.',
                        'Tippe auf den Kochschritt, um weiterzugehen.',
                      ),
                      style: const TextStyle(fontSize: 10),
                    ),
                    onChanged: (v) =>
                        change(() => draft.quickNextTapEnabled = v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      t('Motion', 'Bewegung'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: DropdownButton<String>(
                      value: draft.reduceMotion == null
                          ? 'system'
                          : draft.reduceMotion!
                          ? 'reduced'
                          : 'full',
                      items:
                          [
                                (
                                  'system',
                                  t('Use device setting', 'Geräteeinstellung'),
                                ),
                                ('reduced', t('Reduced', 'Reduziert')),
                                ('full', t('Full', 'Voll')),
                              ]
                              .map(
                                (x) => DropdownMenuItem(
                                  value: x.$1,
                                  child: Text(
                                    x.$2,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => change(
                        () => draft.reduceMotion = v == 'system'
                            ? null
                            : v == 'reduced',
                      ),
                    ),
                  ),
                  SectionLabel(
                    t('Your kitchen notebook', 'Dein Küchennotizbuch'),
                  ),
                  _link(
                    Icons.insights_outlined,
                    t('Shopping insights', 'Einkaufs-Einblicke'),
                    t(
                      'Discover your everyday ingredients',
                      'Deine alltäglichen Zutaten entdecken',
                    ),
                    () => _push(InsightsScreen(state: s)),
                  ),
                  _link(
                    Icons.history,
                    t('Cooking history', 'Kochgeschichte'),
                    t(
                      'Good meals worth remembering',
                      'Gute Mahlzeiten in Erinnerung behalten',
                    ),
                    () => _push(
                      HistoryScreen(
                        state: s,
                        onOpenRecipe: (r) =>
                            _push(DetailScreen(state: s, recipe: r)),
                      ),
                    ),
                  ),
                  _link(
                    Icons.favorite_border,
                    t('Recipe wish list', 'Rezeptwunschliste'),
                    t(
                      '${s.contentRequests.length} ideas, kept on this device',
                      '${s.contentRequests.length} Ideen, auf diesem Gerät gespeichert',
                    ),
                    _wishes,
                  ),
                  SectionLabel(
                    t(
                      'Keep your cookbook close',
                      'Dein Kochbuch sicher aufbewahren',
                    ),
                  ),
                  _link(
                    Icons.ios_share_outlined,
                    t('Back up my kitchen', 'Meine Küche sichern'),
                    t(
                      'Export a JSON & compressed GZip file',
                      'JSON & komprimierte GZip-Datei exportieren',
                    ),
                    busy ? null : _export,
                  ),
                  _link(
                    Icons.file_open_outlined,
                    t('Restore a backup', 'Sicherung wiederherstellen'),
                    t(
                      'Bring your favourites home',
                      'Deine Lieblingsrezepte zurückholen',
                    ),
                    busy ? null : _restore,
                  ),
                  if (busy) const LinearProgressIndicator(minHeight: 2),
                  SectionLabel(t('A helping hand', 'Eine helfende Hand')),
                  _link(
                    Icons.help_outline,
                    t('Help & little answers', 'Hilfe & kleine Antworten'),
                    t('Make yourself at home', 'Mach es dir gemütlich'),
                    () => _push(HelpScreen(state: s)),
                  ),
                  const SizedBox(height: 26),
                  const DashedRule(),
                  const SizedBox(height: 24),
                  Center(child: display('morphcook', size: 36)),
                  const SizedBox(height: 10),
                  Center(
                    child: mono(
                      t(
                        'OFFLINE. PERSONAL. ALWAYS YOURS.',
                        'OFFLINE. PERSÖNLICH. IMMER DEINS.',
                      ),
                      size: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      t(
                        'Version 1.0.0 · made for everyday life',
                        'Version 1.0.0 · für den Alltag gemacht',
                      ),
                      style: const TextStyle(color: Palette.muted, fontSize: 9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: 'MorphCook',
                        applicationVersion: '1.0.0',
                      ),
                      child: Text(
                        t(
                          'Open-source acknowledgements',
                          'Open-Source-Danksagungen',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _link(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? action,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, size: 23, color: Palette.ink),
    title: Text(title, style: const TextStyle(fontSize: 12)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontSize: 9, color: Palette.muted),
    ),
    trailing: const Icon(Icons.arrow_forward, size: 17),
    onTap: action,
  );
  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));
  void _wishes() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            display(t('a little wish list.', 'eine kleine Wunschliste.')),
            const SizedBox(height: 16),
            Text(
              t(
                'Searches with no results are kept here, privately. Your backup includes these ideas. Nothing is sent automatically.',
                'Suchen ohne Treffer werden hier privat gespeichert. Deine Sicherung enthält diese Ideen. Nichts wird automatisch versendet.',
              ),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 16),
            if (widget.state.contentRequests.isEmpty)
              hand(
                t(
                  'room for your next craving.',
                  'Platz für deinen nächsten Appetit.',
                ),
                color: Palette.muted,
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.state.contentRequests.length,
                  itemBuilder: (c, i) => ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: Text(widget.state.contentRequests[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Future<String?> _password({bool exporting = false, String? error}) async {
    final controller = TextEditingController();
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: display(
          exporting
              ? t('keep it close.', 'gut aufgehoben.')
              : t('unlock your cookbook.', 'öffne dein Kochbuch.'),
          size: 28,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exporting
                  ? t(
                      'Add an optional password to encrypt the JSON backup. The companion .gz file is always unencrypted. Choose which file you keep or share.',
                      'Schütze die JSON-Sicherung optional mit einem Passwort. Die zusätzliche .gz-Datei bleibt immer unverschlüsselt. Wähle, welche Datei du aufbewahrst oder teilst.',
                    )
                  : t(
                      'Enter the password used when this backup was created.',
                      'Gib das Passwort ein, mit dem diese Sicherung erstellt wurde.',
                    ),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: t('Password', 'Passwort'),
                errorText: error,
              ),
            ),
            if (exporting)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  t(
                    'Leave empty for a human-readable JSON file.',
                    'Leer lassen für eine lesbare JSON-Datei.',
                  ),
                  style: const TextStyle(fontSize: 9, color: Palette.muted),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Cancel', 'Abbrechen')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              exporting
                  ? t('Export files', 'Dateien exportieren')
                  : t('Unlock', 'Entsperren'),
            ),
          ),
        ],
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    return result;
  }

  Future<void> _export() async {
    final password = await _password(exporting: true);
    if (password == null || !mounted) return;
    setState(() => busy = true);
    try {
      await BackupService.export(
        widget.state.exportBackup(),
        password: password,
      );
      if (mounted) {
        toast(
          context,
          t(
            'Your backup files are ready.',
            'Deine Sicherungsdateien sind bereit.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        toast(
          context,
          t(
            'Could not export the backup. Please try again.',
            'Die Sicherung konnte nicht exportiert werden. Bitte erneut versuchen.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _restore() async {
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || !mounted) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw const FormatException();
      }
      Map<String, dynamic>? data;
      String? password;
      String? message;
      while (data == null) {
        try {
          data = await BackupService.decode(bytes, password: password);
        } on DecryptionException catch (e) {
          if (e.reason == DecryptionReason.passwordRequired ||
              e.reason == DecryptionReason.incorrectPassword) {
            if (!mounted) return;
            password = await _password(error: message);
            if (password == null) return;
            message = t(
              'Incorrect password. Please try again.',
              'Falsches Passwort. Bitte erneut versuchen.',
            );
          } else {
            rethrow;
          }
        }
      }
      if (!mounted) return;
      final backupData = data;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: display(t('welcome back.', 'willkommen zurück.'), size: 29),
          content: Text(
            t(
              'This backup has ${(backupData['saved'] as List).length} saved recipes. Merge keeps your current profile and combines collections. Replace restores the backup profile and all its data.',
              'Diese Sicherung enthält ${(backupData['saved'] as List).length} gespeicherte Rezepte. Zusammenführen behält dein Profil und kombiniert Sammlungen. Ersetzen stellt das Profil und alle Daten der Sicherung wieder her.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('Cancel', 'Abbrechen')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: Text(t('Replace', 'Ersetzen')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'merge'),
              child: Text(t('Merge', 'Zusammenführen')),
            ),
          ],
        ),
      );
      if (choice == null) return;
      await widget.state.importBackup(backupData, merge: choice == 'merge');
      if (mounted) {
        setState(() {
          draft = widget.state.profile.copy();
          name.text = draft.name;
        });
        toast(
          context,
          t(
            'Your kitchen is back in order. Backup restored.',
            'Deine Küche ist wieder da. Sicherung wiederhergestellt.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final en = e is DecryptionException
            ? e.message
            : 'This file is not a valid MorphCook backup.';
        toast(
          context,
          t(
            en,
            e is DecryptionException && e.reason == DecryptionReason.corrupted
                ? 'Die Sicherung ist beschädigt und kann nicht wiederhergestellt werden.'
                : 'Diese Datei ist keine gültige MorphCook-Sicherung.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }
}
