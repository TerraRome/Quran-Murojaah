import 'dart:async';

import 'package:flutter/material.dart';

import 'Quran/application/quran_dependencies.dart';
import 'Quran/quran_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefetch transliteration semua surah di background — tidak blocking UI.
  unawaited(QuranDependencies.transliterationService.prefetchAll());

  runApp(const QuranApp());
}
