import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/context_ext.dart';
import '../../core/localized.dart';
import '../../logic/backup_codec.dart';
import '../../models/profile.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/profile_widgets.dart';
import 'faq_screen.dart';

/// "You & your kitchen" — the settings tab. Lives inside the shell, so it does
/// NOT add its own PaperBackground; the shell already wraps tabs. Every change
/// writes straight back through the profile service; there is no save button,
/// because the right default is "it just keeps your last choice".
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = context.scope.services.profile;
    return ListenableBuilder(
      listenable: profileService,
      builder: (context, _) {
        final p = profileService.profile;
        void update(Profile next) => profileService.update(next);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            _masthead(context),

            // --- Profile -----------------------------------------------------
            _SectionHeader(context.tr('settings.profile')),
            _NameField(
              initial: p.name,
              onChanged: (v) => update(p.copyWith(name: v)),
            ),
            const SizedBox(height: 16),
            MonoLabel(context.tr('settings.language')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Pill(
                    label: 'English',
                    isOn: p.lang == AppLang.en,
                    onTap: () => profileService.setLang(AppLang.en),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Pill(
                    label: 'Deutsch',
                    isOn: p.lang == AppLang.de,
                    onTap: () => profileService.setLang(AppLang.de),
                  ),
                ),
              ],
            ),

            // --- Diet & allergies -------------------------------------------
            _SectionHeader(context.tr('settings.diet')),
            DietPicker(
              selected: p.avoidFlags,
              onChanged: (s) => update(p.copyWith(avoidFlags: s)),
            ),
            const SizedBox(height: 12),
            // Halal / kosher disclaimer — required by spec, sits right under
            // the diet toggles.
            Text(
              context.tr('settings.halal_note'),
              style: const TextStyle(
                fontFamily: Fonts.hand,
                fontSize: 16,
                color: AppColors.inkSoft,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 20),
            MonoLabel(context.tr('settings.avoid_ingredients')),
            const SizedBox(height: 12),
            IngredientAvoidanceField(
              selected: p.avoidIngredients,
              onChanged: (s) => update(p.copyWith(avoidIngredients: s)),
            ),

            // --- Targets -----------------------------------------------------
            _SectionHeader(context.tr('settings.calorie_target')),
            _CalorieTargetControl(profile: p, onChanged: update),
            const SizedBox(height: 8),
            _SwitchTile(
              label: context.tr('settings.calorie_filter'),
              value: p.calorieFilterEnabled,
              onChanged: (v) => update(p.copyWith(calorieFilterEnabled: v)),
            ),
            const SizedBox(height: 22),
            MonoLabel(context.tr('settings.time_budget')),
            const SizedBox(height: 12),
            _TimeBudgetControl(profile: p, onChanged: update),
            const SizedBox(height: 22),
            MonoLabel(context.tr('settings.effort')),
            const SizedBox(height: 12),
            EffortMoodPicker(
              selected: p.preferredEffort,
              onChanged: (id) => update(p.copyWith(preferredEffort: id)),
            ),

            // --- Adaptation --------------------------------------------------
            _SectionHeader(context.tr('settings.adaptation')),
            _SwitchTile(
              label: context.tr('settings.show_tags'),
              value: p.showVariantTags,
              onChanged: (v) => update(p.copyWith(showVariantTags: v)),
            ),

            // --- Accessibility ----------------------------------------------
            _SectionHeader(context.tr('settings.accessibility')),
            MonoLabel(context.tr('settings.reduce_motion')),
            const SizedBox(height: 10),
            _ReduceMotionTriState(
              value: p.reduceMotion,
              onChanged: (v) => update(p.copyWith(reduceMotion: v)),
            ),
            const SizedBox(height: 18),
            _SwitchTile(
              label: context.tr('settings.visual_alert'),
              sub: context.tr('settings.visual_alert_sub'),
              value: p.visualAlertEnabled,
              onChanged: (v) => update(p.copyWith(visualAlertEnabled: v)),
            ),
            const SizedBox(height: 8),
            _SwitchTile(
              label: context.tr('settings.quick_tap'),
              sub: context.tr('settings.quick_tap_sub'),
              value: p.quickNextTapEnabled,
              onChanged: (v) => update(p.copyWith(quickNextTapEnabled: v)),
            ),

            // --- Your data ---------------------------------------------------
            _SectionHeader(context.tr('settings.data')),
            _ActionTile(
              icon: Icons.ios_share,
              label: context.tr('settings.backup'),
              onTap: () => _backupDialog(context),
            ),
            _ActionTile(
              icon: Icons.settings_backup_restore,
              label: context.tr('settings.restore'),
              onTap: () => _restoreDialog(context),
            ),

            // --- Help center -------------------------------------------------
            _SectionHeader(context.tr('settings.help')),
            _ActionTile(
              icon: Icons.help_outline,
              label: context.tr('settings.help'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FaqScreen()),
              ),
            ),

            const SizedBox(height: 30),
            DashedRule(),
            const SizedBox(height: 14),
            Text(
              context.tr('settings.offline_note'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Fonts.mono,
                fontSize: 11,
                letterSpacing: 0.5,
                color: AppColors.inkFaint,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _masthead(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('settings.title').toLowerCase(),
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: 34,
              color: AppColors.ink,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // --- backup / restore dialogs ---------------------------------------------

  Future<void> _backupDialog(BuildContext context) async {
    final pwController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final scope = context.scope;
    final de = context.lang == AppLang.de;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PaperDialog(
        title: ctx.tr('settings.backup'),
        primaryLabel: ctx.tr('backup.export'),
        onPrimary: () => Navigator.of(ctx).pop(true),
        children: [
          TextField(
            controller: pwController,
            obscureText: true,
            style: const TextStyle(
                fontFamily: Fonts.mono, fontSize: 14, color: AppColors.ink),
            decoration: _fieldDecoration(
              ctx.tr('backup.password'),
              hint: ctx.tr('backup.password_hint'),
            ),
          ),
        ],
      ),
    );

    if (go != true) return;
    final pw = pwController.text;
    try {
      await scope.backup.exportToShareSheet(password: pw.isEmpty ? null : pw);
      messenger.showSnackBar(
        SnackBar(content: Text(de ? 'Backup erstellt.' : 'Backup created.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(de
              ? 'Backup konnte nicht erstellt werden.'
              : 'Could not create the backup.'),
        ),
      );
    }
  }

  Future<void> _restoreDialog(BuildContext context) async {
    final pasteController = TextEditingController();
    final pwController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final scope = context.scope;
    final de = context.lang == AppLang.de;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var mode = ImportMode.merge;
        var showPassword = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> submit() async {
              final text = pasteController.text.trim();
              if (text.isEmpty) return;
              final pw = pwController.text;
              final okMsg = ctx.tr('backup.ok');
              try {
                final bytes = utf8.encode(text);
                final map =
                    scope.backup.decode(bytes, password: pw.isEmpty ? null : pw);
                await scope.backup.apply(map, mode);
                if (ctx.mounted) Navigator.of(ctx).pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(okMsg)),
                );
              } on DecryptionException catch (e) {
                final reveal = e.reason == DecryptionReason.passwordRequired ||
                    e.reason == DecryptionReason.wrongPassword;
                setLocal(() {
                  error = e.message(de);
                  if (reveal) showPassword = true;
                });
              }
            }

            return _PaperDialog(
              title: ctx.tr('settings.restore'),
              primaryLabel: ctx.tr('backup.import'),
              onPrimary: submit,
              children: [
                TextField(
                  controller: pasteController,
                  maxLines: 6,
                  minLines: 4,
                  style: const TextStyle(
                      fontFamily: Fonts.mono, fontSize: 12, color: AppColors.ink),
                  decoration: _fieldDecoration(ctx.tr('backup.paste')),
                ),
                const SizedBox(height: 16),
                // merge / replace choice
                _ModeChoice(
                  mode: mode,
                  onChanged: (m) => setLocal(() => mode = m),
                ),
                if (showPassword) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: pwController,
                    obscureText: true,
                    autofocus: true,
                    style: const TextStyle(
                        fontFamily: Fonts.mono,
                        fontSize: 14,
                        color: AppColors.ink),
                    decoration: _fieldDecoration(ctx.tr('backup.password')),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(
                      fontFamily: Fonts.mono,
                      fontSize: 12,
                      color: AppColors.clay,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// --- section header ----------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 14),
      child: Row(
        children: [
          Text(
            title.toLowerCase(),
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: 22,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: DashedRule()),
        ],
      ),
    );
  }
}

// --- name field (keeps its own controller so typing isn't interrupted) -------

class _NameField extends StatefulWidget {
  const _NameField({required this.initial, required this.onChanged});
  final String initial;
  final ValueChanged<String> onChanged;
  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textCapitalization: TextCapitalization.words,
      onChanged: widget.onChanged,
      style: const TextStyle(
        fontFamily: Fonts.display,
        fontStyle: FontStyle.italic,
        fontSize: 20,
        color: AppColors.ink,
      ),
      decoration: _fieldDecoration(context.tr('settings.name')),
    );
  }
}

// --- calorie target ----------------------------------------------------------

class _CalorieTargetControl extends StatelessWidget {
  const _CalorieTargetControl({required this.profile, required this.onChanged});
  final Profile profile;
  final ValueChanged<Profile> onChanged;

  static const _min = 200.0;
  static const _max = 1200.0;

  @override
  Widget build(BuildContext context) {
    final noLimit = profile.calorieTarget == null;
    final cal =
        (profile.calorieTarget ?? 600).toDouble().clamp(_min, _max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: MonoLabel(context.tr('onb.calorie_q'))),
            Text(
              noLimit
                  ? context.tr('onb.no_limit')
                  : '${cal.round()} ${context.tr('common.kcal')}',
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontStyle: FontStyle.italic,
                fontSize: 18,
                color: AppColors.terracotta,
              ),
            ),
          ],
        ),
        Opacity(
          opacity: noLimit ? 0.4 : 1,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.terracotta,
              inactiveTrackColor: AppColors.inkFaint.withValues(alpha: 0.4),
              thumbColor: AppColors.terracotta,
              overlayColor: AppColors.terracotta.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: cal,
              min: _min,
              max: _max,
              divisions: ((_max - _min) / 50).round(),
              onChanged: noLimit
                  ? null
                  : (v) => onChanged(profile.copyWith(calorieTarget: v.round())),
            ),
          ),
        ),
        _SwitchTile(
          label: context.tr('onb.no_limit'),
          value: noLimit,
          onChanged: (v) =>
              onChanged(profile.copyWith(calorieTarget: v ? null : 600)),
        ),
      ],
    );
  }
}

// --- time budget -------------------------------------------------------------

class _TimeBudgetControl extends StatelessWidget {
  const _TimeBudgetControl({required this.profile, required this.onChanged});
  final Profile profile;
  final ValueChanged<Profile> onChanged;

  static const _options = [15, 30, 60];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in _options)
          _Pill(
            label: '$m ${context.tr('common.minutes')}',
            isOn: profile.maxTimeMinutes == m,
            onTap: () => onChanged(profile.copyWith(maxTimeMinutes: m)),
          ),
        _Pill(
          label: context.tr('onb.no_limit'),
          isOn: profile.maxTimeMinutes == null,
          onTap: () => onChanged(profile.copyWith(maxTimeMinutes: null)),
        ),
      ],
    );
  }
}

// --- reduce motion tri-state -------------------------------------------------

class _ReduceMotionTriState extends StatelessWidget {
  const _ReduceMotionTriState({required this.value, required this.onChanged});
  final bool? value; // null=system, true=on, false=off
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final de = context.lang == AppLang.de;
    return Row(
      children: [
        Expanded(
          child: _Pill(
            label: de ? 'System' : 'System',
            isOn: value == null,
            onTap: () => onChanged(null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            label: de ? 'an' : 'on',
            isOn: value == true,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            label: de ? 'aus' : 'off',
            isOn: value == false,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

// --- small reusable controls -------------------------------------------------

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.isOn, required this.onTap});
  final String label;
  final bool isOn;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isOn ? AppColors.terracotta.withValues(alpha: 0.10) : null,
          border: Border.all(
            color: isOn ? AppColors.terracotta : AppColors.inkSoft,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: Fonts.mono,
            fontSize: 13,
            color: isOn ? AppColors.terracotta : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    this.sub,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 16,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: const TextStyle(
                      fontFamily: Fonts.mono,
                      fontSize: 11,
                      color: AppColors.inkFaint,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeThumbColor: AppColors.terracotta,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontSize: 17,
                  color: AppColors.ink,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({required this.mode, required this.onChanged});
  final ImportMode mode;
  final ValueChanged<ImportMode> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Pill(
            label: context.tr('backup.merge'),
            isOn: mode == ImportMode.merge,
            onTap: () => onChanged(ImportMode.merge),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            label: context.tr('backup.replace'),
            isOn: mode == ImportMode.replace,
            onTap: () => onChanged(ImportMode.replace),
          ),
        ),
      ],
    );
  }
}

// --- paper dialog shell ------------------------------------------------------

class _PaperDialog extends StatelessWidget {
  const _PaperDialog({
    required this.title,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
  });
  final String title;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.paper,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toLowerCase(),
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontStyle: FontStyle.italic,
                fontSize: 24,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            DashedRule(),
            const SizedBox(height: 18),
            ...children,
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr('common.cancel'),
                    style: const TextStyle(
                      fontFamily: Fonts.mono,
                      fontSize: 12,
                      letterSpacing: 1.0,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(3),
                  child: InkWell(
                    onTap: onPrimary,
                    borderRadius: BorderRadius.circular(3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      child: Text(
                        primaryLabel,
                        style: const TextStyle(
                          fontFamily: Fonts.mono,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                          color: AppColors.paper,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- shared field decoration -------------------------------------------------

InputDecoration _fieldDecoration(String label, {String? hint}) {
  return InputDecoration(
    isDense: true,
    labelText: label,
    labelStyle: const TextStyle(
      fontFamily: Fonts.mono,
      fontSize: 12,
      letterSpacing: 1.0,
      color: AppColors.inkSoft,
    ),
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamily: Fonts.mono,
      fontSize: 11,
      color: AppColors.inkFaint,
    ),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.inkFaint),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.terracotta),
    ),
  );
}
