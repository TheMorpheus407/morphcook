/// Settings hub + sub-screens: profile editor, appearance,
/// backup & restore, help center, kitchen reference, about, re-onboard.
library;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'backup.dart';
import 'faq.dart';
import 'guide.dart';
import 'morph.dart';
import 'onboarding.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);

    Widget row(IconData icon, String title, {Widget? trailing, VoidCallback? onTap, Widget? child}) {
      return Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Palette.inkSoft),
            title: Text(title, style: T.body.copyWith(color: Palette.ink)),
            trailing: trailing,
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          if (child != null) child,
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(m.t('set.title'))),
      body: ListenableBuilder(
        listenable: Listenable.merge([m.store, m.loc]),
        builder: (context, _) {
          final p2 = m.profile;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Text(m.t('set.profile'), style: T.section.copyWith(letterSpacing: 2.4)),
              ListTile(
                leading: Icon(Icons.badge_outlined, color: Palette.inkSoft),
                title: Text(m.t('set.name'), style: T.body),
                trailing: Text(p2.name.isEmpty ? '—' : p2.name, style: T.mono),
                onTap: () => _nameSheet(m),
              ),
              row(
                Icons.translate,
                m.t('set.language'),
                trailing: SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(value: 'en', label: Text('EN')),
                    const ButtonSegment(value: 'de', label: Text('DE')),
                  ],
                  selected: {p2.lang},
                  onSelectionChanged: (s) => m.loc.set(s.first),
                ),
              ),
              row(
                Icons.block,
                m.t('set.diet'),
                trailing: Text(p2.avoidFlags.isEmpty ? '—' : '${p2.avoidFlags.length}', style: T.mono),
                onTap: () => _flagSheet(m),
              ),
              row(
                Icons.format_list_bulleted,
                m.t('set.avoid-list'),
                trailing: Text(p2.avoidIngredients.isEmpty ? '—' : '${p2.avoidIngredients.length}', style: T.mono),
                onTap: () => _avoidIngredientSheet(m),
              ),
              row(
                  Icons.priority_high,
                  m.t('set.required'),
                  trailing: Text(
                      p2.requiredAttributes.isEmpty ? '—' : '${p2.requiredAttributes.length}',
                      style: T.mono),
                  onTap: () {
                    final req = m.c.compoundFlags
                        .where((f) =>
                            f.id == 'halal-compat' || f.id == 'kosher-compat')
                        .toList();
                    for (final f in req) {
                      if (p2.requiredAttributes.contains(f.id)) {
                        p2.requiredAttributes.remove(f.id);
                        m.store.updateProfile(p2.clone());
                      }
                    }
                    setState(() {});
                  }),
              Text(m.t('set.halal-note'),
                  style: T.caption.copyWith(height: 1.5),
                  textAlign: TextAlign.justify),

              const Divider(),
              Text(m.t('ob.calories'), style: T.section.copyWith(letterSpacing: 2.4)),
              row(
                Icons.local_fire_department_outlined,
                '${m.t('set.calories')} ±${m.t('set.tolerance')}',
                trailing:
                    Text('${p2.calorieTarget} kcal', style: T.mono),
                onTap: () => _sliderSheet(m, 'kcal',
                    lo: 200, hi: 1400, value: p2.calorieTarget.toDouble(),
                    onDone: (v) {
                      p2.calorieTarget = v;
                      m.store.updateProfile(p2.clone());
                      setState(() {});
                    }),
              ),
              Text('${m.t('set.time')} · ${m.t('set.effort')}',
                  style: T.section.copyWith(letterSpacing: 2.4)),
              row(
                Icons.timer,
                m.t('set.time'),
                trailing: Text('${p2.maxTimeMinutes} min', style: T.mono),
                onTap: () => _sliderSheet(m, 'min',
                    lo: 15, hi: 240, value: p2.maxTimeMinutes.toDouble(),
                    onDone: (v) {
                      p2.maxTimeMinutes = v;
                      m.store.updateProfile(p2.clone());
                      setState(() {});
                    }),
              ),
              row(
                Icons.restaurant_menu,
                m.t('set.effort'),
                trailing: Text(m.t('effort.${p2.preferredEffort}'), style: T.mono),
                onTap: () => _effortSheet(m),
              ),

              const Divider(),
              Text(m.t('set.appearance'), style: T.section.copyWith(letterSpacing: 2.4)),
              _switch( m.t('set.show-tags'), p2.showVariantTags,
                  (v) {
                p2.showVariantTags = v;
                m.store.updateProfile(p2.clone());
                setState(() {});
              }),
              _switch( m.t('set.reduce-motion'), p2.reduceMotion,
                  (v) {
                p2.reduceMotion = v;
                m.store.updateProfile(p2.clone());
                setState(() {});
              }),
              _switch( m.t('set.visual-alerts'), p2.visualAlerts,
                  (v) {
                p2.visualAlerts = v;
                m.store.updateProfile(p2.clone());
                setState(() {});
              }),
              _switch( m.t('set.quick-tap'), p2.quickNextTap,
                  (v) {
                p2.quickNextTap = v;
                m.store.updateProfile(p2.clone());
                setState(() {});
              }),

              const Divider(),
              ListTile(
                leading: Icon(Icons.backup_outlined, color: Palette.inkSoft),
                title: Text(m.t('set.backup'),
                    style: T.body.copyWith(color: Palette.ink)),
                trailing: const Icon(Icons.chevron_right, color: Palette.inkFaint),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const BackupScreen())),
              ),
              ListTile(
                leading: Icon(Icons.help_outline, color: Palette.inkSoft),
                title: Text(m.t('set.help'),
                    style: T.body.copyWith(color: Palette.ink)),
                trailing: const Icon(Icons.chevron_right, color: Palette.inkFaint),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const FaqScreen())),
              ),
              ListTile(
                leading: Icon(Icons.menu_book_outlined, color: Palette.inkSoft),
                title:
                    Text(m.t('set.guide'), style: T.body.copyWith(color: Palette.ink)),
                trailing: const Icon(Icons.chevron_right, color: Palette.inkFaint),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const GuideScreen())),
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: Palette.inkSoft),
                title: Text(m.t('set.about'),
                    style: T.body.copyWith(color: Palette.ink)),
                trailing: const Icon(Icons.chevron_right, color: Palette.inkFaint),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => _AboutPage())),
              ),
              ListTile(
                leading: Icon(Icons.replay, color: Palette.inkSoft),
                title: Text(m.t('set.onboard'),
                    style: T.body.copyWith(color: Palette.ink)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: Palette.cardPaper,
                      title: Text(m.t('set.onboard'), style: T.h2),
                      content: Text(m.t('ob.welcome'), style: T.body),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(m.t('common.cancel'), style: T.body)),
                        TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child:
                                Text(m.t('ob.begin'), style: T.body)),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const OnboardingShell()),
                  );
                  if (!mounted) return;
                  m.store.setOnboarded(true);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _switch(String label, bool value, void Function(bool) onChanged) {
    return SwitchListTile(
      value: value,
      title: Text(label, style: T.body.copyWith(color: Palette.ink)),
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    );
  }

  void _nameSheet(MorphData m) {
    final c = TextEditingController(text: m.profile.name);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.paper,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.t('ob.name'), style: T.h2),
            const SizedBox(height: 12),
            TextField(
                controller: c,
                    decoration: InputDecoration(
                        hintText: 'e.g. M., Alex, Sam',
                        labelText: m.t('set.name')),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            Align(
                alignment: Alignment.centerRight,
                child: InkButton(
                    label: m.t('common.save'),
                    filled: true,
                    small: true,
                    onTap: () {
                      m.profile.name = c.text.trim();
                      m.store.updateProfile(m.profile.clone());
                      Navigator.pop(context);
                    })),
          ],
        ),
      ),
    );
  }

  void _flagSheet(MorphData m) {
    final p = m.profile;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Palette.cardPaper,
            title: Text(m.t('set.diet'), style: T.h2),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in m.c.compoundFlags)
                    CheckboxListTile(
                      dense: true,
                      value: p.avoidFlags.contains(f.id),
                      title: Text(
                          f.expandsTo.length > 2
                              ? '${f.id} · ${f.expandsTo.length} flags'
                              : f.id,
                          style: T.body.copyWith(color: Palette.ink)),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            p.avoidFlags.add(f.id);
                          } else {
                            p.avoidFlags.remove(f.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(m.t('common.cancel'), style: T.body)),
              TextButton(
                  onPressed: () {
                    m.store.updateProfile(p.clone());
                    Navigator.pop(context);
                  },
                  child: Text(m.t('common.save'), style: T.body)),
            ],
          );
        },
      ),
    );
  }

  void _avoidIngredientSheet(MorphData m) {
    final p = m.profile;
    final q = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.paper,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          List<IngredientMeta> hits = m.c.ingredients.values.toList();
          final text = q.text.trim().toLowerCase();
          if (text.isNotEmpty) {
            hits = hits
                .where((met) =>
                    met.name.s('en').toLowerCase().contains(text) ||
                    met.name.s('de').toLowerCase().contains(text) ||
                    met.id.contains(text))
                .toList();
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.t('ob.avoid'), style: T.h2),
                Text(m.t('ob.avoid.sub'),
                    style: T.body.copyWith(fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                    controller: q,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'e.g. cilantro, dairy, peanuts'),
                    onChanged: (v) => setState(() {
                          hits = m.c.ingredients.values.toList();
                          final t = v.trim().toLowerCase();
                          if (t.isNotEmpty) {
                            hits = hits
                                .where((met) =>
                                    met.name.s('en').toLowerCase().contains(t) ||
                                    met.name.s('de').toLowerCase().contains(t) ||
                                    met.id.contains(t))
                                .toList();
                          }
                        })),
                const SizedBox(height: 6),
                Flexible(
                    child: SizedBox(
                        height: 200,
                        child: ListView(
                            children: [
                              for (final met in hits)
                                CheckboxListTile(
                                  dense: true,
                                  value: p.avoidIngredients.contains(met.id),
                                  title: Text(met.name.s(m.lang),
                                      style: T.body.copyWith(color: Palette.ink)),
                                  subtitle:
                                      Text(met.aisle, style: T.caption),
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        p.avoidIngredients.add(met.id);
                                      } else {
                                        p.avoidIngredients.remove(met.id);
                                      }
                                    });
                                  },
                                ),
                            ]))),
                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerRight,
                    child: InkButton(
                        label: m.t('common.save'),
                        filled: true,
                        small: true,
                        onTap: () {
                          m.store.updateProfile(p.clone());
                          Navigator.pop(context);
                        })),
              ],
            ),
          );
        },
      ),
    );
  }

  void _sliderSheet(MorphData m, String unit,
      {required double lo,
      required double hi,
      required double value,
      required void Function(int) onDone}) {
    var v = value;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Palette.cardPaper,
            title: Text(unit, style: T.h2),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(v.toStringAsFixed(0),
                    style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontStyle: FontStyle.italic,
                        fontSize: 40,
                        color: Palette.ink)),
                Slider(
                  value: v,
                  min: lo,
                  max: hi,
                  label: v.toStringAsFixed(0),
                  onChanged: (vv) => setState(() => v = vv),
                ),
                Text('${lo.toInt()} – ${hi.toInt()}', style: T.caption),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(m.t('common.cancel'), style: T.body)),
              TextButton(
                  onPressed: () {
                    onDone(v.round());
                    Navigator.pop(context);
                  },
                  child: Text(m.t('common.save'), style: T.body)),
            ],
          );
        },
      ),
    );
  }

  void _effortSheet(MorphData m) {
    final p = m.profile;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Palette.cardPaper,
            title: Text(m.t('set.effort'), style: T.h2),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in ['easy', 'medium', 'hard'])
                  ListTile(
                    dense: true,
                    leading: Icon(
                      p.preferredEffort == e
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: p.preferredEffort == e
                          ? Palette.coral
                          : Palette.inkFaint,
                    ),
                    title: Text(m.t('effort.$e'),
                        style: T.body.copyWith(color: Palette.ink)),
                    onTap: () => setState(() {
                          p.preferredEffort = e;
                          m.store.updateProfile(p.clone());
                        }),
                  ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(m.t('common.close'), style: T.body)),
            ],
          );
        },
      ),
    );
  }
}

class OnboardingShell extends StatelessWidget {
  const OnboardingShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPage();
  }
}

class _AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final n = m.c.recipes.length;
    final d = m.c.dishes.length;
    return Scaffold(
      appBar: AppBar(title: Text(m.t('set.about'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(m.t('app.name'),
              style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontStyle: FontStyle.italic,
                  fontSize: 34,
                  color: Palette.ink)),
          const SizedBox(height: 6),
          Text(m.t('about.v1'), style: T.hand.copyWith(fontSize: 22)),
          const SizedBox(height: 16),
          Text(m.t('about.built'),
              style: T.body.copyWith(height: 1.6)),
          const SizedBox(height: 12),
          Text(m.tf('about.corpus', {'n': '$n', 'd': '$d'}),
              style: T.body.copyWith(height: 1.6)),
          const SizedBox(height: 20),
          Container(height: 1, color: Palette.ink.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
          for (final cat in m.c.faqCategories.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(cat.value[m.lang] ?? 'en', style: T.body),
                  ),
                  Text(m.t('faq.all'), style: T.caption),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text('· morphcook — offline, yours',
              style: T.hand.copyWith(color: Palette.teal)),
        ],
      ),
    );
  }
}
