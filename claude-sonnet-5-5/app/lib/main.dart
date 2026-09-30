import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/theme/typography.dart';
import 'data/bundle_asset_source.dart';
import 'platform/real_platform_services.dart';
import 'state/app_services.dart';
import 'state/storage/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship inside the app (assets/google_fonts); nothing is fetched at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['Playfair Display, JetBrains Mono, Caveat'], text);
  });
  runApp(const _Bootstrap());
}

/// Shows a paper splash while storage and the corpus load, then the app.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<AppServices> _services = _create();

  Future<AppServices> _create() async {
    final storage = await AppStorage.openDefault();
    return AppServices.create(
      assets: BundleAssetSource(),
      storage: storage,
      platform: systemPlatformServices(),
      deviceLanguage: ui.PlatformDispatcher.instance.locale.languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snapshot) {
        if (snapshot.hasData) return MorphCookApp(services: snapshot.data!);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: Scaffold(
            backgroundColor: Palette.paper,
            body: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        kDebugMode ? '${snapshot.error}' : 'MorphCook could not start.',
                        style: AppText.mono(),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('morphcook', style: AppText.display(size: 44)),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
