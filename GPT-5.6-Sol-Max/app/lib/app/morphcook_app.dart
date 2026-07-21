import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../screens/main_shell.dart';
import '../screens/onboarding_screen.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';

class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: controller,
    child: Consumer<AppController>(
      builder: (context, app, _) => MaterialApp(
        title: 'MorphCook',
        debugShowCheckedModeBanner: false,
        theme: BrandTheme.light(),
        locale: Locale(app.language),
        supportedLocales: const [Locale('en'), Locale('de')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _BootstrapGate(),
      ),
    ),
  );
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  Object? _error;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        initializeDateFormatting('de_DE'),
        initializeDateFormatting('en_US'),
        context.read<AppController>().initialize(),
      ]);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    if (_error != null) {
      return Scaffold(
        body: PaperBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'MorphCook could not open its local cookbook.\n$_error',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _initialize();
                    },
                    child: const Text('TRY AGAIN'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!app.initialized) return const _Splash();
    return AnimatedSwitcher(
      duration: app.profile.reduceMotion == true
          ? Duration.zero
          : const Duration(milliseconds: 380),
      child: app.profile.onboardingComplete
          ? const MainShell(key: ValueKey('main'))
          : const OnboardingScreen(key: ValueKey('onboarding')),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PaperBackground(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MorphCook', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 11),
            const Text(
              'a complete recipe book for every body',
              style: TextStyle(
                fontFamily: 'Caveat',
                fontSize: 23,
                color: BrandColors.coral,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    ),
  );
}
