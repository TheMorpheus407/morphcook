import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_container.dart';
import 'theme/brand_theme.dart';

void main() {
  // Ensure Flutter engine is initialized before shared preferences loading
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MorphCookApp());
}

class MyAppScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // Custom scrollbar removal for cleaner, paper-like pages
  }
}

class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            scrollBehavior: MyAppScrollBehavior(),
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: BrandColors.creamBg,
              primaryColor: BrandColors.charcoalInk,
              colorScheme: ColorScheme.fromSeed(
                seedColor: BrandColors.coral,
                background: BrandColors.creamBg,
                primary: BrandColors.charcoalInk,
                secondary: BrandColors.coral,
                tertiary: BrandColors.teal,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: BrandColors.creamBg,
                elevation: 0,
                centerTitle: false,
              ),
              checkboxTheme: CheckboxThemeData(
                fillColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return BrandColors.coral;
                  }
                  return Colors.transparent;
                }),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              sliderTheme: SliderThemeData(
                activeTrackColor: BrandColors.coral,
                inactiveTrackColor: BrandColors.dashedLine,
                thumbColor: BrandColors.charcoalInk,
                overlayColor: BrandColors.coral.withOpacity(0.12),
                valueIndicatorColor: BrandColors.charcoalInk,
                showValueIndicator: ShowValueIndicator.always,
              ),
              chipTheme: const ChipThemeData(
                backgroundColor: BrandColors.paleCream,
                selectedColor: BrandColors.coral,
                secondarySelectedColor: BrandColors.teal,
                brightness: Brightness.light,
                labelStyle: TextStyle(color: BrandColors.charcoalInk),
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              ),
            ),
            home: _HomeRouter(provider: provider),
          );
        },
      ),
    );
  }
}

class _HomeRouter extends StatelessWidget {
  final AppProvider provider;

  const _HomeRouter({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.isLoaded) {
      return const Scaffold(
        body: PaperGrainBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "morphcook",
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 36.0,
                    fontStyle: FontStyle.italic,
                    color: BrandColors.charcoalInk,
                  ),
                ),
                SizedBox(height: 16.0),
                CircularProgressIndicator(color: BrandColors.coral),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.onboardingCompleted) {
      return const MainNavigationContainer();
    } else {
      return const OnboardingScreen();
    }
  }
}
