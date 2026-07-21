import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/morphcook_app.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(MorphCookApp(controller: AppController()));
}
