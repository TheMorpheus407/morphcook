import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/paper_background.dart';
import 'home/home_shell.dart';
import 'onboarding/onboarding_flow.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final state = AppScope.of(context);
    if (state.profileRepo.profile.onboarded) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    return Scaffold(
      body: PaperBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.appName.toLowerCase(),
                style: MCTypography.display(size: 64),
              ),
              const SizedBox(height: 4),
              HandwrittenNote(
                text: '— ${s.tagline}.',
                color: MCColors.coral,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
