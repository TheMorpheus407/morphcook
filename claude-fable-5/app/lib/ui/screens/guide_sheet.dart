import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';

/// "Kitchen reference" bottom sheet — educational ingredient content.
void showGuideSheet(BuildContext context, String ingredientId) {
  final morph = MorphTheme.of(context);
  final state = context.read<AppState>();
  final entry = state.corpus.guide[ingredientId];
  if (entry == null) return;
  final lang = state.lang;
  final s = S(lang);
  final name =
      state.corpus.dictionary.byId(ingredientId)?.name.of(lang) ??
          ingredientId;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: morph.colors.paper,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6))),
    isScrollControlled: true,
    builder: (context) {
      final morph = MorphTheme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            Center(
                child:
                    Text(s('kitchenReference'), style: morph.text.label())),
            const SizedBox(height: 8),
            Center(
              child: Text(morph.cased(name),
                  style: morph.text.display.copyWith(fontSize: 30)),
            ),
            const SizedBox(height: 12),
            Text(entry.description.of(lang),
                style: morph.text.mono.copyWith(fontSize: 12.5)),
            const DashedDivider(),
            _block(morph, s('tips'), entry.tips.of(lang)),
            _block(morph, s('storage'), entry.storage.of(lang)),
            _block(morph, s('whereToFind'), entry.whereToFind.of(lang)),
          ],
        ),
      );
    },
  );
}

Widget _block(MorphThemeData morph, String label, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(morph.cased(label), style: morph.text.label()),
          const SizedBox(height: 4),
          Text(body,
              style: morph.text.handAt(19, color: morph.colors.ink)),
        ],
      ),
    );
