import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/expert_assessment.dart';
import '../../models/recipe.dart';
import 'recipe_sharing_screen.dart';

class ExpertAssessmentsScreen extends StatelessWidget {
  final Recipe recipe;
  const ExpertAssessmentsScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    String tr(String en, String de) => state.lang == 'de' ? de : en;
    final current = state.personalRecipeById(recipe.id)?.asRecipe() ?? recipe;
    final fingerprint = expertRecipeFingerprint(current);
    final entries =
        state.expertAssessments.where((e) => e.recipeId == recipe.id).toList()
          ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Expert assessments', 'Fachliche Einschätzungen')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            current.title.of(state.lang),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              'Ask a qualified nutrition or health professional to assess this exact recipe. Share the recipe, explain your question to them, then record their response here. MorphCook does not provide expert reviews or verify credentials.',
              'Bitte eine qualifizierte Ernährungs- oder Gesundheitsfachkraft um eine Einschätzung dieses konkreten Rezepts. Teile das Rezept, erläutere deine Frage und halte die Antwort hier fest. MorphCook bietet keine eigenen Fachbewertungen und prüft keine Qualifikationen.',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('request-expert-review'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecipeSharingScreen(recipeId: recipe.id),
              ),
            ),
            icon: const Icon(Icons.share_outlined),
            label: Text(
              tr(
                'Request a review · share recipe',
                'Einschätzung anfragen · Rezept teilen',
              ),
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('record-expert-assessment'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _AssessmentEditor(recipe: current),
              ),
            ),
            icon: const Icon(Icons.note_add_outlined),
            label: Text(tr('Record assessment', 'Einschätzung erfassen')),
          ),
          Text(
            tr(
              'These private notes are included in full backups, but excluded from recipe sharing. They do not change dietary labels or nutrition estimates.',
              'Diese privaten Notizen sind in vollständigen Backups enthalten, aber nicht beim Teilen von Rezepten. Sie ändern weder Ernährungskennzeichnungen noch Nährwertschätzungen.',
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Text(
              tr(
                'No assessments recorded.',
                'Noch keine Einschätzungen erfasst.',
              ),
            ),
          for (final entry in entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.expertName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(entry.qualifications),
                    Text(
                      entry.reviewedAt.toUtc().toIso8601String().substring(
                        0,
                        10,
                      ),
                    ),
                    Text(
                      tr(
                        'Recorded by you · credentials unverified',
                        'Von dir erfasst · Qualifikation ungeprüft',
                      ),
                    ),
                    if (entry.recipeFingerprint != fingerprint)
                      Text(
                        tr(
                          'Recipe changed since this assessment was recorded. Request a new review before applying it.',
                          'Das Rezept wurde seit der Erfassung geändert. Bitte vor der Anwendung erneut fachlich prüfen lassen.',
                        ),
                        key: const ValueKey('assessment-recipe-changed'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 8),
                    SelectableText(entry.assessment),
                    if (entry.source.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(
                          '${tr('Source', 'Quelle')}: ${entry.source}',
                        ),
                      ),
                    TextButton(
                      onPressed: () => _delete(context, entry, state.lang),
                      child: Text(tr('Delete note', 'Notiz löschen')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    ExpertAssessment entry,
    String lang,
  ) async {
    String tr(String en, String de) => lang == 'de' ? de : en;
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr('Delete this assessment?', 'Diese Einschätzung löschen?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel', 'Abbrechen')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete', 'Löschen')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await state.deleteExpertAssessment(entry.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Could not delete the note. Try again.',
                'Notiz konnte nicht gelöscht werden. Bitte erneut versuchen.',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _AssessmentEditor extends StatefulWidget {
  final Recipe recipe;
  const _AssessmentEditor({required this.recipe});
  @override
  State<_AssessmentEditor> createState() => _AssessmentEditorState();
}

class _AssessmentEditorState extends State<_AssessmentEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _qualifications = TextEditingController();
  final _assessment = TextEditingController();
  final _source = TextEditingController();
  final _date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final controller in [
      _name,
      _qualifications,
      _assessment,
      _source,
      _date,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    String tr(String en, String de) => lang == 'de' ? de : en;
    Widget field(
      String key,
      TextEditingController controller,
      String label,
      int limit, {
      int lines = 1,
      bool optional = false,
    }) => TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !_saving,
      maxLength: limit,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      decoration: InputDecoration(labelText: label),
      validator: (value) => !optional && (value == null || value.trim().isEmpty)
          ? tr('Required', 'Erforderlich')
          : null,
    );
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Record assessment', 'Einschätzung erfassen')),
        ),
        body: Form(
          key: _form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    'Record an assessment you actually received for the current recipe. Include the expert’s qualifications and relevant context. The app cannot verify this information.',
                    'Erfasse eine tatsächlich erhaltene Einschätzung zum aktuellen Rezept, einschließlich Qualifikation und relevantem Kontext. Die App kann diese Angaben nicht prüfen.',
                  ),
                ),
                field(
                  'expert-name',
                  _name,
                  tr('Expert name', 'Name der Fachkraft'),
                  120,
                ),
                field(
                  'expert-qualifications',
                  _qualifications,
                  tr('Qualifications', 'Qualifikation'),
                  300,
                ),
                TextFormField(
                  key: const ValueKey('expert-date'),
                  controller: _date,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: tr(
                      'Review date (YYYY-MM-DD)',
                      'Datum der Einschätzung (JJJJ-MM-TT)',
                    ),
                  ),
                  maxLength: 10,
                  validator: (value) {
                    if (parseExpertReviewDate(value ?? '') == null) {
                      return tr(
                        'Enter a valid past or present date.',
                        'Gültiges heutiges oder vergangenes Datum eingeben.',
                      );
                    }
                    return null;
                  },
                ),
                field(
                  'expert-assessment',
                  _assessment,
                  tr('Assessment and context', 'Einschätzung und Kontext'),
                  4000,
                  lines: 4,
                ),
                field(
                  'expert-source',
                  _source,
                  tr(
                    'Source or reference (optional)',
                    'Quelle oder Beleg (optional)',
                  ),
                  1000,
                  lines: 2,
                  optional: true,
                ),
                if (_error != null)
                  Text(_error!, key: const ValueKey('expert-save-error')),
                if (_saving) const LinearProgressIndicator(),
                FilledButton(
                  key: const ValueKey('save-expert-assessment'),
                  onPressed: _saving ? null : () => _save(lang),
                  child: Text(
                    tr('Save private note', 'Private Notiz speichern'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(String lang) async {
    if (!_form.currentState!.validate()) return;
    final reviewedAt = parseExpertReviewDate(_date.text);
    if (reviewedAt == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = ExpertAssessment(
        recipeId: widget.recipe.id,
        recipeFingerprint: expertRecipeFingerprint(widget.recipe),
        expertName: _name.text,
        qualifications: _qualifications.text,
        assessment: _assessment.text,
        source: _source.text,
        reviewedAt: reviewedAt,
      );
      await context.read<AppState>().saveExpertAssessment(entry);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = lang == 'de'
              ? 'Speichern fehlgeschlagen. Speicher prüfen oder bei geändertem Rezept das Formular erneut öffnen.'
              : 'Could not save. Check storage, or reopen this form if the recipe changed.';
        });
      }
    }
  }
}
