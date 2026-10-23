import 'dart:async';

import 'package:flutter/material.dart';

import 'Quran/application/quran_dependencies.dart';
import 'Quran/quran_app.dart';
import 'Quran/shalat/application/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefetch transliteration semua surah di background — tidak blocking UI.
  unawaited(QuranDependencies.transliterationService.prefetchAll());
  // Plugin notifikasi harus siap sebelum ada jadwal yang dipasang.
  unawaited(NotificationService.init());
  // Muat log progres murojaah + pengingat harian sebelum halaman pertama dibuka.
  unawaited(_startProgress());

  runApp(const QuranApp());
}

/// Muat log, sambungkan pemicu penjadwalan ulang, lalu pasang jadwal pengingat.
Future<void> _startProgress() async {
  final progress = QuranDependencies.murojaahProgress;
  final reminder = QuranDependencies.reminder;

  progress.onRecorded = (result, activeToday) =>
      reminder.onRecorded(result, activeToday: activeToday);

  await progress.load();
  await reminder.load();
  final snapshot = progress.snapshot();
  await reminder.sync(
    activeToday: snapshot.activeToday,
    streak: snapshot.streak,
  );
}
