import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient_dictionary.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingScreen({super.key, this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0: lang, 1: name, 2: diet & allergies, 3: cal & time, 4: confirm
  late String _lang;
  late TextEditingController _nameController;
  late Set<String> _avoidFlags;
  late Set<String> _avoidIngredients;
  late Set<String> _requiredAttributes;
  late int _calorieTarget;
  late bool _calorieFilterEnabled;
  late int _maxTimeMinutes;
  late String _preferredEffort;
  String _ingredientQuery = '';

  static const _dietPresets = [
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
  ];

  static const _classAvoidOptions = [
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
  void initState() {
    super.initState();
    final current = context.read<MorphCookAppState>().profile;
    _lang = current.lang;
    _nameController = TextEditingController(text: current.name);
    _avoidFlags = Set<String>.from(current.avoidFlags);
    _avoidIngredients = Set<String>.from(current.avoidIngredients);
    _requiredAttributes = Set<String>.from(current.requiredAttributes);
    _calorieTarget = current.calorieTarget;
    _calorieFilterEnabled = current.calorieFilterEnabled;
    _maxTimeMinutes = current.maxTimeMinutes;
    _preferredEffort = current.preferredEffort;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isDe => _lang == 'de';

  UserProfile _buildDraftProfile(UserProfile base) {
    final trimmedName = _nameController.text.trim();
    return base.copyWith(
      name: trimmedName.isEmpty ? (_isDe ? 'Köchin/Koch' : 'Cook') : trimmedName,
      lang: _lang,
      avoidFlags: _avoidFlags,
      avoidIngredients: _avoidIngredients,
      requiredAttributes: _requiredAttributes,
      calorieTarget: _calorieTarget,
      calorieFilterEnabled: _calorieFilterEnabled,
      maxTimeMinutes: _maxTimeMinutes,
      preferredEffort: _preferredEffort,
      onboardingCompleted: true,
    );
  }

  Future<void> _finishOnboarding() async {
    final appState = context.read<MorphCookAppState>();
    final updated = _buildDraftProfile(appState.profile);
    await appState.completeOnboarding(updated);
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();

    return Scaffold(
      body: PaperGrainBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Vintage header bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'morphcook  ·  no. 0${_step + 1}/05',
                      style: NostalgicTheme.mono(
                        fontSize: 12,
                        color: NostalgicPalette.terracotta,
                      ),
                    ),
                    Text(
                      _isDe ? 'persönliches kochbuch' : 'personal kitchen ledger',
                      style: NostalgicTheme.handwritten(
                        fontSize: 18,
                        color: NostalgicPalette.fadedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: DashedRule(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                  child: _buildStepContent(appState),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: DashedRule(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton(
                        onPressed: () => setState(() => _step -= 1),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NostalgicPalette.ink,
                          side: const BorderSide(color: NostalgicPalette.mutedRule),
                        ),
                        child: Text(
                          _isDe ? '← zurück' : '← back',
                          style: NostalgicTheme.mono(
                            fontSize: 12,
                            color: NostalgicPalette.ink,
                          ),
                        ),
                      ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('onboarding_next_btn'),
                      onPressed: () {
                        if (_step < 4) {
                          setState(() => _step += 1);
                        } else {
                          _finishOnboarding();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: NostalgicPalette.terracotta,
                        foregroundColor: NostalgicPalette.cardStock,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _step < 4
                            ? (_isDe ? 'weiter →' : 'continue →')
                            : (_isDe
                                ? 'kochbuch öffnen ✦'
                                : 'open my cookbook ✦'),
                        style: NostalgicTheme.mono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: NostalgicPalette.cardStock,
                        ),
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

  Widget _buildStepContent(MorphCookAppState appState) {
    switch (_step) {
      case 0:
        return _buildLanguageStep();
      case 1:
        return _buildNameStep();
      case 2:
        return _buildDietAndAllergiesStep(appState);
      case 3:
        return _buildCalorieAndTimeStep();
      case 4:
      default:
        return _buildConfirmStep(appState);
    }
  }

  Widget _buildLanguageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isDe
              ? 'In welcher Sprache kochst du?'
              : 'Which language belongs on your kitchen table?',
          style: NostalgicTheme.serifDisplay(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          _isDe
              ? 'Jedes Gericht existiert vollständig auf Deutsch & Englisch.'
              : 'Every dish is authored in full across English & German.',
          style: NostalgicTheme.serifBody(
            fontSize: 15.5,
            color: NostalgicPalette.fadedInk,
          ),
        ),
        const SizedBox(height: 24),
        _languageOptionCard(
          code: 'en',
          title: 'English',
          subtitle: '“Every human’s way of eating deserves a complete recipe book.”',
        ),
        const SizedBox(height: 14),
        _languageOptionCard(
          code: 'de',
          title: 'Deutsch',
          subtitle: '„Jede Art zu essen verdient ein vollständiges eigenes Kochbuch.“',
        ),
      ],
    );
  }

  Widget _languageOptionCard({
    required String code,
    required String title,
    required String subtitle,
  }) {
    final selected = _lang == code;
    return InkWell(
      key: ValueKey('onboarding_lang_$code'),
      onTap: () => setState(() => _lang = code),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? NostalgicPalette.terracotta.withValues(alpha: 0.12)
              : NostalgicPalette.cardStock,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? NostalgicPalette.terracotta
                : NostalgicPalette.mutedRule,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: NostalgicTheme.serifDisplay(fontSize: 21),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: NostalgicTheme.handwritten(
                      fontSize: 18,
                      color: NostalgicPalette.fadedInk,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? NostalgicPalette.terracotta
                  : NostalgicPalette.mutedRule,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isDe
              ? 'Wem gehört dieses Kochbuch?'
              : 'Whose name goes on the front cover?',
          style: NostalgicTheme.serifDisplay(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          _isDe
              ? 'Bleibt 100 % lokal auf deinem Gerät — kein Konto, keine Cloud.'
              : 'Stays 100% offline on your device—no account, no cloud.',
          style: NostalgicTheme.serifBody(
            fontSize: 15,
            color: NostalgicPalette.fadedInk,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey('onboarding_name_input'),
          controller: _nameController,
          style: NostalgicTheme.serifDisplay(
            fontSize: 22,
            fontStyle: FontStyle.normal,
          ),
          decoration: InputDecoration(
            labelText: _isDe ? 'Dein Vorname' : 'Your first name',
            labelStyle: NostalgicTheme.mono(fontSize: 12),
            filled: true,
            fillColor: NostalgicPalette.cardStock,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NostalgicPalette.cardStock,
            border: Border.all(color: NostalgicPalette.mutedRule),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ex libris culinaria',
                style: NostalgicTheme.mono(
                  fontSize: 10.5,
                  color: NostalgicPalette.terracotta,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isDe
                    ? '${_nameController.text.trim().isEmpty ? "Deine" : _nameController.text.trim()}s Küchen-Ausgabe'
                    : '${_nameController.text.trim().isEmpty ? "Your" : "${_nameController.text.trim()}’s"} Kitchen Ledger',
                style: NostalgicTheme.serifDisplay(fontSize: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDietAndAllergiesStep(MorphCookAppState appState) {
    final dict = appState.ingredients;
    final matchingNodes = dict.search(_ingredientQuery, _lang, limit: 12);
    final expandedIngredients = dict.expandAvoidedIngredients(_avoidIngredients);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isDe ? 'Ernährung & Unverträglichkeiten' : 'Diet & Ingredient Avoidance',
          style: NostalgicTheme.serifDisplay(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          _isDe
              ? 'Gerichte verschwinden nie — wir schalten direkt auf deine Variante um.'
              : 'Dishes never disappear—we surface the variant written for you.',
          style: NostalgicTheme.serifBody(
            fontSize: 14.5,
            color: NostalgicPalette.fadedInk,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _isDe ? '1. ernährungsweise (shortcuts)' : '1. dietary presets',
          style: NostalgicTheme.mono(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: NostalgicPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dietPresets.map((preset) {
            final selected = _avoidFlags.contains(preset);
            return FilterChip(
              key: ValueKey('diet_preset_$preset'),
              selected: selected,
              label: Text(appState.ontology.labelForFlag(preset, _lang)),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _avoidFlags.add(preset);
                  } else {
                    _avoidFlags.remove(preset);
                  }
                });
              },
            );
          }).toList(),
        ),
        if (_avoidFlags.contains('halal') || _avoidFlags.contains('kosher')) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NostalgicPalette.agedPaper,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: NostalgicPalette.mutedRule),
            ),
            child: Text(
              _isDe
                  ? 'Hinweis: Wir kennzeichnen „halal-kompatible“ bzw. „koscher-kompatible Zutaten“ (ohne Schwein, Alkohol, nicht-konforme Gelatine). Zertifizierung ist eine Eigenschaft von Einkauf & Schlachtung, nicht eines Rezepttexts.'
                  : 'Note: We surface halal-compatible and kosher-compatible ingredients only. Certification is a property of sourcing (slaughter, supervision), not of a recipe text.',
              style: NostalgicTheme.mono(
                fontSize: 11,
                color: NostalgicPalette.ink,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          _isDe
              ? '2. kategorien ausschließen (class avoidance)'
              : '2. class avoidance (checkboxes)',
          style: NostalgicTheme.mono(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: NostalgicPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _classAvoidOptions.map((flag) {
            final selected = _avoidFlags.contains(flag);
            return FilterChip(
              key: ValueKey('class_avoid_$flag'),
              selected: selected,
              label: Text(appState.ontology.labelForFlag(flag, _lang)),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _avoidFlags.add(flag);
                  } else {
                    _avoidFlags.remove(flag);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Text(
          _isDe
              ? '3. spezifische zutaten ausschließen (mit baum-vererbung)'
              : '3. specific ingredient avoidance (hierarchical tree)',
          style: NostalgicTheme.mono(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: NostalgicPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('onboarding_ingredient_typeahead'),
          decoration: InputDecoration(
            hintText: _isDe
                ? 'Zutat suchen (z. B. Koriander, Käse, Erdnüsse, Äpfel)…'
                : 'Typeahead search (e.g. cilantro, cheese, apples, dairy)…',
            hintStyle: NostalgicTheme.mono(fontSize: 11.5),
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: NostalgicPalette.cardStock,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _ingredientQuery = v),
        ),
        const SizedBox(height: 8),
        if (_avoidIngredients.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _avoidIngredients.map((id) {
              final node = dict[id];
              final descCount = dict.descendantsOf(id).length - 1;
              return InputChip(
                label: Text(
                  descCount > 0
                      ? '${node?.name.resolve(_lang) ?? id} (+$descCount)'
                      : (node?.name.resolve(_lang) ?? id),
                  style: NostalgicTheme.mono(
                    fontSize: 11,
                    color: NostalgicPalette.cardStock,
                  ),
                ),
                backgroundColor: NostalgicPalette.terracotta,
                deleteIconColor: NostalgicPalette.cardStock,
                onDeleted: () => setState(() => _avoidIngredients.remove(id)),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            _isDe
                ? 'Baum-Propagation aktiv: ${expandedIngredients.length} Zutaten-Knoten ausgeschlossen.'
                : 'Tree propagation active: ${expandedIngredients.length} ingredient nodes excluded.',
            style: NostalgicTheme.handwritten(
              fontSize: 16,
              color: NostalgicPalette.sage,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          constraints: const BoxConstraints(maxHeight: 190),
          decoration: BoxDecoration(
            color: NostalgicPalette.cardStock,
            border: Border.all(color: NostalgicPalette.mutedRule),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: matchingNodes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final IngredientNode node = matchingNodes[idx];
              final isSelected = _avoidIngredients.contains(node.id);
              final isInherited =
                  !isSelected && expandedIngredients.contains(node.id);
              return ListTile(
                dense: true,
                title: Text(
                  dict.breadcrumbFor(node.id, _lang),
                  style: NostalgicTheme.serifBody(fontSize: 14),
                ),
                subtitle: node.isCategory
                    ? Text(
                        _isDe
                            ? 'Schließt alle ${dict.descendantsOf(node.id).length - 1} Unterzutaten ein'
                            : 'Propagates to ${dict.descendantsOf(node.id).length - 1} child ingredients',
                        style: NostalgicTheme.mono(
                          fontSize: 10.5,
                          color: NostalgicPalette.sage,
                        ),
                      )
                    : null,
                trailing: Icon(
                  isSelected
                      ? Icons.check_box
                      : (isInherited
                          ? Icons.subdirectory_arrow_right
                          : Icons.add_circle_outline),
                  size: 18,
                  color: isSelected
                      ? NostalgicPalette.terracotta
                      : NostalgicPalette.fadedInk,
                ),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _avoidIngredients.remove(node.id);
                    } else {
                      _avoidIngredients.add(node.id);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieAndTimeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isDe
              ? 'Zeitbudget, Aufwand & Kalorienziel'
              : 'Time Budget, Effort Mood & Calories',
          style: NostalgicTheme.serifDisplay(fontSize: 26),
        ),
        const SizedBox(height: 8),
        Text(
          _isDe
              ? 'Deine Standardwerte für den Alltag. Auf jeder Gerichtseite kannst du frei zwischen Varianten wechseln.'
              : 'Your everyday defaults. You can still switch variants on any dish page.',
          style: NostalgicTheme.serifBody(
            fontSize: 14.5,
            color: NostalgicPalette.fadedInk,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _isDe
              ? 'maximale kochzeit: $_maxTimeMinutes min.'
              : 'max cooking time: $_maxTimeMinutes min',
          style: NostalgicTheme.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: NostalgicPalette.ink,
          ),
        ),
        Slider(
          value: _maxTimeMinutes.toDouble().clamp(15, 90),
          min: 15,
          max: 90,
          divisions: 5,
          activeColor: NostalgicPalette.terracotta,
          label: '$_maxTimeMinutes min',
          onChanged: (v) => setState(() => _maxTimeMinutes = v.round()),
        ),
        const SizedBox(height: 16),
        Text(
          _isDe ? 'bevorzugter aufwand heute' : 'preferred effort mood',
          style: NostalgicTheme.mono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: NostalgicPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: ['easy', 'medium', 'hard'].map((eff) {
            final selected = _preferredEffort == eff;
            return ChoiceChip(
              selected: selected,
              label: Text(eff),
              onSelected: (_) => setState(() => _preferredEffort = eff),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _isDe
                ? 'Kalorienziel als festen Filter aktivieren'
                : 'Enable hard calorie target filter',
            style: NostalgicTheme.serifBody(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _isDe
                ? 'Pro Gericht jederzeit per Schalter übersteuerbar.'
                : 'Can be overridden per dish with a single switch.',
            style: NostalgicTheme.mono(fontSize: 11),
          ),
          value: _calorieFilterEnabled,
          activeThumbColor: NostalgicPalette.terracotta,
          onChanged: (v) => setState(() => _calorieFilterEnabled = v),
        ),
        if (_calorieFilterEnabled) ...[
          Text(
            '~$_calorieTarget kcal / serving (±250 kcal)',
            style: NostalgicTheme.mono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: NostalgicPalette.terracotta,
            ),
          ),
          Slider(
            value: _calorieTarget.toDouble().clamp(350, 850),
            min: 350,
            max: 850,
            divisions: 10,
            activeColor: NostalgicPalette.terracotta,
            onChanged: (v) => setState(() => _calorieTarget = v.round()),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmStep(MorphCookAppState appState) {
    final draft = _buildDraftProfile(appState.profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isDe ? 'Deine Ausgabe ist bereit.' : 'Your kitchen edition is ready.',
          style: NostalgicTheme.serifDisplay(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          _isDe
              ? 'Keine Kompromisse, keine gestrichenen Gerichte.'
              : 'No compromises, no missing dishes.',
          style: NostalgicTheme.handwritten(
            fontSize: 21,
            color: NostalgicPalette.terracotta,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: NostalgicPalette.cardStock,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: NostalgicPalette.mutedRule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✦ ${draft.name.toLowerCase()} · ${draft.lang.toUpperCase()}',
                style: NostalgicTheme.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NostalgicPalette.terracotta,
                ),
              ),
              const SizedBox(height: 10),
              const DashedRule(),
              const SizedBox(height: 10),
              _summaryRow(
                _isDe ? 'Aufwand & Zeit' : 'Effort & Time',
                '${draft.preferredEffort} · ≤ ${draft.maxTimeMinutes} min',
              ),
              const SizedBox(height: 6),
              _summaryRow(
                _isDe ? 'Kalorienziel' : 'Calorie Target',
                draft.calorieFilterEnabled
                    ? '~${draft.calorieTarget} kcal (±${draft.calorieTolerance})'
                    : (_isDe ? 'Alle Stufen sichtbar' : 'All calorie levels shown'),
              ),
              const SizedBox(height: 6),
              _summaryRow(
                _isDe ? 'Ausgeschlossene Klassen' : 'Avoided Flags',
                draft.avoidFlags.isEmpty
                    ? (_isDe ? 'Keine' : 'None')
                    : draft.avoidFlags.join(', '),
              ),
              const SizedBox(height: 6),
              _summaryRow(
                _isDe ? 'Ausgeschlossene Zutaten' : 'Avoided Ingredients',
                draft.avoidIngredients.isEmpty
                    ? (_isDe ? 'Keine' : 'None')
                    : draft.avoidIngredients.join(', '),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(
            label.toLowerCase(),
            style: NostalgicTheme.mono(
              fontSize: 11,
              color: NostalgicPalette.fadedInk,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: NostalgicTheme.serifBody(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
