import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/reminder_settings_section.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/progress/record_result.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_controller.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.granted = true});

  bool granted;
  bool settingsOpened = false;
  final List<DateTime> scheduled = [];

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async => scheduled.add(at);

  @override
  Future<void> cancel() async => scheduled.clear();

  @override
  Future<void> openSystemSettings() async => settingsOpened = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeScheduler scheduler;
  late MurojaahProgressController progress;
  late MurojaahReminder reminder;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduler = _FakeScheduler();
    progress = MurojaahProgressController(store: MemoryActivityStore());
    await progress.load();
    reminder = MurojaahReminder(
      scheduler: scheduler,
      clock: () => DateTime(2026, 10, 23, 9),
    );
  });

  Widget app({bool dark = false}) => MaterialApp(
    theme: QuranTokens.themeData(dark),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ReminderSettingsSection(reminder: reminder, progress: progress),
        ],
      ),
    ),
  );

  Future<void> narrow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: app(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bagian pengingat: saklar, jam, dan status di 360px teks 2x', (
    tester,
  ) async {
    await narrow(tester);

    expect(find.text('Pengingat'), findsOneWidget);
    expect(find.text('Pengingat harian'), findsOneWidget);
    expect(find.text('sekitar 20:00'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('izin ditolak: penjelasan + jalan ke pengaturan, bukan error', (
    tester,
  ) async {
    scheduler.granted = false;
    await narrow(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(reminder.enabled, isFalse);
    expect(
      find.textContaining('Izin notifikasi belum diberikan'),
      findsOneWidget,
    );
    expect(find.text('Buka pengaturan sistem'), findsOneWidget);

    await tester.ensureVisible(find.text('Buka pengaturan sistem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka pengaturan sistem'));
    await tester.pumpAndSettle();
    expect(scheduler.settingsOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saklar nyala memasang jadwal harian', (tester) async {
    await narrow(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(reminder.enabled, isTrue);
    expect(scheduler.scheduled.first, DateTime(2026, 10, 23, 20));
  });

  testWidgets('record memicu penjadwalan ulang lewat controller progres', (
    tester,
  ) async {
    var seen = RecordResult.none;
    progress.onRecorded = (result, activeToday) => seen = result;

    await progress.record(surahNumber: 1, fromVerse: 1, toVerse: 1);

    expect(seen.streakIncreased, isTrue);
  });
}
