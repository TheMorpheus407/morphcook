import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';
import 'backup_restore_screen.dart';
import 'faq_screen.dart';
import 'onboarding_screen.dart';
import 'shopping_insights_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ingredientQueryCtrl = TextEditingController();

  static const _compoundDiets = [
    'vegan',
    'vegetarian',
    'pescatarian',
    'halal',
    'kosher',
    'gluten-free',
    'dairy-free',
    'low-fodmap',
    'sugar-free',
    'nut-free',
    'lactose-free',
  ];

  static const _classFlags = [
    'dairy',
    'gluten',
    'peanuts',
    'tree-nuts',
    'shellfish',
    'fish',
    'egg',
    'soy',
    'pork',
    'beef',
    'lamb',
    'poultry',
    'alcohol',
    'honey',
    'sesame',
  ];

  @override
  void dispose() {
    _ingredientQueryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final profile = appState.profile;
    final lang = profile.lang;
    final isDe = lang == 'de';
    final dict = appState.ingredients;
    final matchingNodes = dict.search(_ingredientQueryCtrl.text, lang, limit: 8);

    return PaperGrainBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
        children: [
          Text(
            isDe ? 'einstellungen & küchen-profil' : 'settings & kitchen profile',
            style: NostalgicTheme.serifDisplay(fontSize: 26),
          ),
          const SizedBox(height: 6),
          const DashedRule(),
          const SizedBox(height: 12),

          // Quick Utility Links: Shopping Insights, Backup/Restore, FAQ, Onboarding
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('settings_open_insights_btn'),
                icon: const Icon(Icons.insights, size: 16),
                label: Text(isDe ? 'Einkaufs-Insights' : 'Shopping Insights'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ShoppingInsightsScreen(),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('settings_open_backup_btn'),
                icon: const Icon(Icons.import_export, size: 16),
                label: Text(isDe ? 'Backup & Restore' : 'Backup & Restore'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BackupRestoreScreen(),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('settings_open_faq_btn'),
                icon: const Icon(Icons.help_outline, size: 16),
                label: Text(isDe ? 'FAQ & Hilfe' : 'FAQ / Help Center'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FaqScreen(),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('settings_rerun_onboarding_btn'),
                icon: const Icon(Icons.auto_stories_outlined, size: 16),
                label: Text(isDe ? 'Onboarding starten' : 'Onboarding'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
          DashedRule(label: isDe ? 'sprache & name' : 'language & identity'),
          const SizedBox(height: 10),

          // Language & Name Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NostalgicPalette.cardStock,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: NostalgicPalette.mutedRule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isDe ? 'Sprache:' : 'Language:',
                      style: NostalgicTheme.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NostalgicPalette.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      key: const ValueKey('settings_lang_en'),
                      selected: lang == 'en',
                      label: const Text('EN · English'),
                      onSelected: (_) => appState.setLanguage('en'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      key: const ValueKey('settings_lang_de'),
                      selected: lang == 'de',
                      label: const Text('DE · Deutsch'),
                      onSelected: (_) => appState.setLanguage('de'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      isDe ? 'Bevorzugter Aufwand:' : 'Preferred Effort:',
                      style: NostalgicTheme.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NostalgicPalette.ink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    for (final eff in ['easy', 'medium', 'hard'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: profile.preferredEffort == eff,
                          label: Text(eff),
                          onSelected: (_) => appState.updateProfile(
                            profile.copyWith(preferredEffort: eff),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          DashedRule(
            label: isDe
                ? 'ernährungsweise & halal/koscher-hinweis'
                : 'dietary flags & halal/kosher note',
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NostalgicPalette.cardStock,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: NostalgicPalette.mutedRule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _compoundDiets.map((flag) {
                    final selected = profile.avoidFlags.contains(flag);
                    return FilterChip(
                      key: ValueKey('settings_diet_$flag'),
                      selected: selected,
                      label: Text(appState.ontology.labelForFlag(flag, lang)),
                      onSelected: (val) {
                        final next = Set<String>.from(profile.avoidFlags);
                        if (val) {
                          next.add(flag);
                        } else {
                          next.remove(flag);
                        }
                        appState.updateProfile(profile.copyWith(avoidFlags: next));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Explicit Halal / Kosher Sourcing Note required by SPEC.md lines 352-357
                Container(
                  key: const ValueKey('halal_kosher_sourcing_note'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NostalgicPalette.agedPaper,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: NostalgicPalette.mutedRule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDe
                            ? '✦ Hinweis zu Halal & Koscher (halal-compatible ingredients)'
                            : '✦ Halal & Kosher Note (halal-compatible ingredients)',
                        style: NostalgicTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: NostalgicPalette.terracotta,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDe
                            ? 'Wir verwenden niemals die Bezeichnung „halal-zertifiziert“ oder „koscher-zertifiziert“. Wir kennzeichnen ausschließlich „halal-kompatible Zutaten“ bzw. „koscher-kompatible Zutaten“. Zertifizierung ist eine Eigenschaft der Herkunft (Schlachtung, Aufsicht), nicht eines Rezepttexts.'
                            : 'We never claim "halal-certified" or "kosher-certified" in UI copy. We surface "halal-compatible ingredients" only. Certification is a property of sourcing (slaughter, supervision), not of a recipe text.',
                        style: NostalgicTheme.serifBody(fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isDe
                      ? 'kategorien-ausschluss (class avoidance):'
                      : 'class avoidance checkboxes:',
                  style: NostalgicTheme.mono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: NostalgicPalette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _classFlags.map((flag) {
                    final selected = profile.avoidFlags.contains(flag);
                    return FilterChip(
                      selected: selected,
                      label: Text(appState.ontology.labelForFlag(flag, lang)),
                      onSelected: (val) {
                        final next = Set<String>.from(profile.avoidFlags);
                        if (val) {
                          next.add(flag);
                        } else {
                          next.remove(flag);
                        }
                        appState.updateProfile(profile.copyWith(avoidFlags: next));
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          DashedRule(
            label: isDe
                ? 'spezifischer zutaten-ausschluss (baum)'
                : 'specific ingredient avoidance (tree)',
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NostalgicPalette.cardStock,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: NostalgicPalette.mutedRule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('settings_ingredient_typeahead'),
                  controller: _ingredientQueryCtrl,
                  decoration: InputDecoration(
                    hintText: isDe
                        ? 'Zutat suchen (z. B. Koriander, Käse, Erdnüsse)…'
                        : 'Typeahead ingredient search (e.g. cilantro, cheese, apples)…',
                    hintStyle: NostalgicTheme.mono(fontSize: 11),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (profile.avoidIngredients.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profile.avoidIngredients.map((id) {
                      final node = dict[id];
                      return InputChip(
                        label: Text(node?.name.resolve(lang) ?? id),
                        onDeleted: () {
                          final next = Set<String>.from(profile.avoidIngredients)
                            ..remove(id);
                          appState.updateProfile(
                            profile.copyWith(avoidIngredients: next),
                          );
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                ...matchingNodes.take(5).map((node) {
                  final selected = profile.avoidIngredients.contains(node.id);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      dict.breadcrumbFor(node.id, lang),
                      style: NostalgicTheme.serifBody(fontSize: 14),
                    ),
                    trailing: Icon(
                      selected ? Icons.check_circle : Icons.add_circle_outline,
                      color: selected
                          ? NostalgicPalette.terracotta
                          : NostalgicPalette.fadedInk,
                      size: 18,
                    ),
                    onTap: () {
                      final next = Set<String>.from(profile.avoidIngredients);
                      if (selected) {
                        next.remove(node.id);
                      } else {
                        next.add(node.id);
                      }
                      appState.updateProfile(
                        profile.copyWith(avoidIngredients: next),
                      );
                    },
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 18),
          DashedRule(
            label: isDe
                ? 'kalorien, zeit & barrierefreiheit'
                : 'calories, time & accessibility',
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NostalgicPalette.cardStock,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: NostalgicPalette.mutedRule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  key: const ValueKey('settings_calorie_filter_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isDe
                        ? 'Kalorienziel als Filter (~${profile.calorieTarget} kcal)'
                        : 'Calorie Target Filter (~${profile.calorieTarget} kcal)',
                    style: NostalgicTheme.serifBody(fontWeight: FontWeight.w600),
                  ),
                  value: profile.calorieFilterEnabled,
                  onChanged: (v) => appState.updateProfile(
                    profile.copyWith(calorieFilterEnabled: v),
                  ),
                ),
                Slider(
                  value: profile.calorieTarget.toDouble().clamp(350, 850),
                  min: 350,
                  max: 850,
                  divisions: 10,
                  activeColor: NostalgicPalette.terracotta,
                  label: '${profile.calorieTarget} kcal',
                  onChanged: (v) => appState.updateProfile(
                    profile.copyWith(calorieTarget: v.round()),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  key: const ValueKey('settings_visual_alert_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isDe
                        ? 'Visueller Timer-Blitzalarm (Korall/Blaugrün)'
                        : 'Visual Flash Alert on Timer Completion (Coral/Teal)',
                    style: NostalgicTheme.serifBody(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isDe
                        ? 'Für gehörlose/schwerhörige Köche im Kochmodus (visualAlertEnabled).'
                        : 'Accessibility alert for deaf/hard-of-hearing users (visualAlertEnabled).',
                    style: NostalgicTheme.mono(fontSize: 10.5),
                  ),
                  value: profile.visualAlertEnabled,
                  onChanged: (v) => appState.updateProfile(
                    profile.copyWith(visualAlertEnabled: v),
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('settings_quick_tap_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isDe
                        ? 'Einhand-Tippen im Kochmodus (quickNextTapEnabled)'
                        : 'One-Handed Quick-Tap in Cook Mode (quickNextTapEnabled)',
                    style: NostalgicTheme.serifBody(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isDe
                        ? 'Einfaches Tippen auf den Schritt blättert weiter (300ms Entprellung).'
                        : 'Single tap on step content advances to next step (300ms debounce).',
                    style: NostalgicTheme.mono(fontSize: 10.5),
                  ),
                  value: profile.quickNextTapEnabled,
                  onChanged: (v) => appState.updateProfile(
                    profile.copyWith(quickNextTapEnabled: v),
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('settings_reduce_motion_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isDe
                        ? 'Bewegung reduzieren (reduceMotion)'
                        : 'Reduce Motion (reduceMotion)',
                    style: NostalgicTheme.serifBody(fontWeight: FontWeight.w600),
                  ),
                  value: profile.reduceMotion ?? false,
                  onChanged: (v) => appState.updateProfile(
                    profile.copyWith(reduceMotion: v),
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
