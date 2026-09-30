import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../logic/matching.dart';
import '../../logic/variant_selector.dart';
import '../../models/ontology.dart';
import '../../state/profile_controller.dart';

/// Keeps only the most specific flags ({meat, beef} → {beef}).
List<String> specificFlags(Set<String> flags, Ontology onto) {
  final ancestors = <String>{};
  for (final f in flags) {
    var p = onto.flagParents[f];
    while (p != null) {
      ancestors.add(p);
      p = onto.flagParents[p];
    }
  }
  final out = flags.where((f) => !ancestors.contains(f) && f != 'meat-dairy-combo').toList()..sort();
  if (out.isEmpty && flags.contains('meat-dairy-combo')) out.add('meat-dairy-combo');
  return out;
}

/// Human wording for why a recipe doesn't fit — quiet, factual, no machinery.
String blockReasonText(BuildContext context, MatchResult m) {
  final tr = context.trRead;
  final repo = context.read<CorpusRepository>();
  final profile = context.read<ProfileController>().profile;
  final lang = tr.lang;
  if (m.reasons.isEmpty) return '';
  switch (m.reasons.first) {
    case BlockReason.avoidedFlag:
      final labels = specificFlags(m.flags, repo.ontology).take(2).map((f) => repo.ontology.flagLabel(f, lang));
      return tr('variant.blocked.flag', {'what': labels.join(', ')});
    case BlockReason.avoidedIngredient:
      final names = m.ingredients.take(2).map((i) => repo.ingredients.name(i, lang));
      return tr('variant.blocked.ingredient', {'what': names.join(', ')});
    case BlockReason.missingAttribute:
      final names = m.missingAttributes.take(2).map((a) => repo.ontology.label('requirable', a, lang));
      return tr('variant.blocked.attribute', {'what': names.join(', ')});
    case BlockReason.overTime:
      return tr('variant.blocked.time', {'n': profile.maxTimeMinutes ?? 0});
    case BlockReason.calories:
      return tr('variant.blocked.calories');
  }
}

String optionNote(BuildContext context, DimensionRow row, DimensionOption o) {
  final tr = context.trRead;
  final onto = context.read<CorpusRepository>().ontology;
  final lang = tr.lang;
  switch (o.state) {
    case OptionState.unwritten:
      final dims = onto.dimensions;
      final labels = [
        for (var i = 0; i < o.fixed.length; i++) onto.dimensionValueLabel(dims[i].field, o.fixed[i], lang),
        onto.dimensionValueLabel(row.def.field, o.value, lang),
      ];
      return tr('variant.unwritten', {'combo': labels.join(' × ')});
    case OptionState.blocked:
      return o.block == null ? '' : blockReasonText(context, o.block!);
    default:
      return '';
  }
}
