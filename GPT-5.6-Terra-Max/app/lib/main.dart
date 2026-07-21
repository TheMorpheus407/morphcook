import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'app_state.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MorphCookApp());
}

class MorphCookApp extends StatefulWidget {
  const MorphCookApp({super.key});

  @override
  State<MorphCookApp> createState() => _MorphCookAppState();
}

class _MorphCookAppState extends State<MorphCookApp> {
  late final Future<MorphCookState> _startup;

  @override
  void initState() {
    super.initState();
    _startup = MorphCookState.bootstrap();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MorphCookState>(
    future: _startup,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: morphTheme(),
          home: Scaffold(
            body: PaperGrain(
              child: Center(
                child: snapshot.hasError
                    ? const Text('MorphCook could not open its local cookbook.')
                    : const CircularProgressIndicator(color: MorphColors.teal),
              ),
            ),
          ),
        );
      }
      final state = snapshot.data!;
      return MorphCookScope(
        state: state,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MorphCook',
          theme: morphTheme(),
          home: const AppEntry(),
        ),
      );
    },
  );
}

/// Switches the root content whenever the persisted app state changes.
///
/// `MaterialApp.home` is configured once by [MorphCookApp], so reading the
/// onboarding flag there leaves the onboarding route in place after it is
/// completed. This widget is below [MorphCookScope] and therefore rebuilds
/// when [MorphCookState] notifies its listeners.
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    return state.onboardingComplete
        ? const AppShell()
        : const OnboardingScreen();
  }
}
