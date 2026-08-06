import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'data/corpus_repository.dart';
import 'state/app_model.dart';
import 'state/library_model.dart';
import 'ui/root_shell.dart';

class MorphCookApp extends StatelessWidget {
  final AppModel appModel;
  final LibraryModel library;
  final CorpusRepository corpus;

  const MorphCookApp({
    super.key,
    required this.appModel,
    required this.library,
    required this.corpus,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appModel),
        ChangeNotifierProvider.value(value: library),
        Provider.value(value: corpus),
      ],
      child: Consumer<AppModel>(
        builder: (context, model, _) {
          return InheritedStrings(
            strings: model.strings,
            child: MaterialApp(
              title: 'MorphCook',
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              home: const RootShell(),
            ),
          );
        },
      ),
    );
  }
}
