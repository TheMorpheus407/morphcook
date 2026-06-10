import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'localization/i18n.dart';
import 'screens/splash_screen.dart';
import 'theme/theme.dart';

class MorphCookApp extends StatefulWidget {
  final AppState state;
  const MorphCookApp({super.key, required this.state});

  @override
  State<MorphCookApp> createState() => _MorphCookAppState();
}

class _MorphCookAppState extends State<MorphCookApp> {
  late final LanguageNotifier _lang;

  @override
  void initState() {
    super.initState();
    _lang = LanguageNotifier(widget.state.profileRepo.profile.lang);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: I18n(
        notifier: _lang,
        child: AnimatedBuilder(
          animation: _lang,
          builder: (context, child) {
            return MaterialApp(
              title: 'MorphCook',
              debugShowCheckedModeBanner: false,
              theme: buildLightTheme(),
              locale: Locale(_lang.lang),
              supportedLocales: const [
                Locale('en'),
                Locale('de'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const SplashScreen(),
            );
          },
        ),
      ),
    );
  }
}
