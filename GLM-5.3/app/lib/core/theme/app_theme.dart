import 'package:flutter/material.dart';

/// The nostalgic-calm palette: warm paper, soft ink, muted coral / teal /
/// mustard accents. No pure black, no pure white.
class AppColors {
  AppColors._();

  static const paper = Color(0xFFF5EEE1);
  static const paperDeep = Color(0xFFEDE3D0);
  static const paperCard = Color(0xFFFCF8EF);
  static const ink = Color(0xFF2E2A24);
  static const inkSoft = Color(0xFF6B6455);
  static const inkFaint = Color(0xFFA79E8C);
  static const coral = Color(0xFFD96A5B);
  static const coralDeep = Color(0xFFB54A3C);
  static const teal = Color(0xFF3E7C74);
  static const tealDeep = Color(0xFF2C5F58);
  static const mustard = Color(0xFFC9A85C);
  static const cookInk = Color(0xFFEDE3D0); // cook mode foreground on dark
  static const cookBg = Color(0xFF221F1B);
}

/// Light theme for the paper world.
ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.teal,
      secondary: AppColors.coral,
      surface: AppColors.paperCard,
      onSurface: AppColors.ink,
    ),
    canvasColor: AppColors.paper,
    dividerColor: AppColors.inkFaint,
    splashColor: AppColors.teal.withOpacity(0.08),
    highlightColor: AppColors.mustard.withOpacity(0.12),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(color: AppColors.paper, fontSize: 13),
      behavior: SnackBarBehavior.floating,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return AppColors.teal;
        return Colors.transparent;
      }),
      side: const BorderSide(color: AppColors.teal, width: 1.4),
      checkColor: MaterialStateProperty.all(AppColors.paper),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected) ? AppColors.paper : AppColors.paperCard),
      trackColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected) ? AppColors.teal : AppColors.inkFaint),
    ),
  );
}
