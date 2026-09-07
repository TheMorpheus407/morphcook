import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/profile.dart';
import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import 'profile_widgets.dart';

/// Full profile editor: what you avoid, what you need, how much time you have.
class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late Profile _draft;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _draft = context.read<AppController>().profile;
    _name = TextEditingController(text: _draft.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(Profile p) => setState(() => _draft = p);

  Future<void> _save() async {
    final app = context.read<AppController>();
    final s = context.s;
    await app.updateProfile(_draft.copyWith(name: _name.text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('profile.saved'))));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    const pad = EdgeInsets.symmetric(horizontal: 20);
    const headerPad = EdgeInsets.fromLTRB(20, 24, 20, 10);
    return Scaffold(
      appBar: AppBar(title: Text(s('profile.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionHeader(title: s('profile.name'), padding: headerPad),
          Padding(
            padding: pad,
            child: TextField(
              controller: _name,
              style: AppText.body(size: 15),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: s('onb.name.hint')),
            ),
          ),
          SectionHeader(title: s('profile.styles'), kicker: s('profile.styles.note'), padding: headerPad),
          Padding(padding: pad, child: DietStylePicker(value: _draft, onChanged: _set)),
          SectionHeader(title: s('profile.classes'), kicker: s('profile.classes.note'), padding: headerPad),
          Padding(padding: pad, child: AllergenPicker(value: _draft, onChanged: _set)),
          SectionHeader(title: s('profile.specific'), padding: headerPad),
          Padding(padding: pad, child: SpecificAvoidanceField(value: _draft, onChanged: _set)),
          SectionHeader(title: s('profile.required'), kicker: s('profile.required.note'), padding: headerPad),
          Padding(padding: pad, child: RequirementsPicker(value: _draft, onChanged: _set)),
          const Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 0), child: DashedRule()),
          SectionHeader(title: s('profile.calories'), kicker: s('profile.calories.note', {'tol': '${_draft.calorieTolerance}'}), padding: headerPad),
          Padding(padding: pad, child: CalorieTargetField(value: _draft, onChanged: _set)),
          SectionHeader(title: s('profile.time'), kicker: s('profile.time.note'), padding: headerPad),
          Padding(padding: pad, child: TimeBudgetField(value: _draft, onChanged: _set)),
          SectionHeader(title: s('profile.effort'), kicker: s('profile.effort.note'), padding: headerPad),
          Padding(padding: pad, child: EffortPicker(value: _draft, onChanged: _set)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.rule))),
          child: PaperButton(label: s('common.save'), expand: true, icon: Icons.check, onPressed: _save),
        ),
      ),
    );
  }
}
