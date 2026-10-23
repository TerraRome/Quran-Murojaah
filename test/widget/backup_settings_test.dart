import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/murojaah/backup/backup_controller.dart';
import 'package:quran/Quran/murojaah/backup/backup_document.dart';
import 'package:quran/Quran/murojaah/backup/backup_sharer.dart';
import 'package:quran/Quran/murojaah/presentation/widgets/backup_settings_section.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_controller.dart';
import 'package:quran/Quran/murojaah/reminder/reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements ReminderScheduler {
  final List<DateTime> scheduled = [];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> hasPermission() async => true;

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
  Future<void> openSystemSettings() async {}
}

class _FakeSharer implements BackupSharer {
  String? shared;

  @override
  Future<bool> share(String json) async {
    shared = json;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSharer sharer;
  late MurojaahProgressController progress;
  late MurojaahReminder reminder;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharer = _FakeSharer();
    progress = MurojaahProgressController(store: MemoryActivityStore());
    await progress.load();
    reminder = MurojaahReminder(
      scheduler: _FakeScheduler(),
      clock: () => DateTime(2026, 10, 23, 9),
    );
    await reminder.load();
  });

  Widget app() => MaterialApp(
    theme: QuranTokens.themeData(false),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          BackupSettingsSection(
            progress: progress,
            reminder: reminder,
            sharer: sharer,
          ),
        ],
      ),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: app(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ekspor memanggil sharer dengan JSON berskema', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Ekspor data'));
    await tester.pumpAndSettle();

    expect(sharer.shared, isNotNull);
    expect(sharer.shared, contains('"backupVersion"'));
    expect(sharer.shared, contains('"entries"'));
    expect(find.textContaining('disiapkan'), findsOneWidget);
  });

  testWidgets('salin cadangan menaruh JSON di papan klip', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester);
    await tester.tap(find.text('Salin cadangan'));
    await tester.pumpAndSettle();

    expect(copied, hasLength(1));
    expect(copied.single, contains('"backupVersion"'));
    expect(copied.single, contains('"entries"'));
    expect(find.textContaining('Cadangan disalin'), findsOneWidget);
  });

  testWidgets('impor menampilkan ringkasan lalu menambah entri', (tester) async {
    await pump(tester);

    // Berkas berisi satu entri yang belum ada di perangkat.
    final seeded = BackupDocument(
      entries: [
        ActivityEntry(
          id: 'x1',
          at: DateTime(2026, 10, 22, 8),
          surahNumber: 2,
          fromVerse: 1,
          toVerse: 2,
        ),
      ],
      goalVerses: 15,
      reminderEnabled: false,
      reminderHour: 20,
      reminderMinute: 0,
    ).encode();

    await tester.tap(find.text('Impor data'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), seeded);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Periksa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 entri baru'), findsOneWidget);

    await tester.tap(find.text('Impor'));
    await tester.pumpAndSettle();

    expect(progress.entries.length, 1);
    expect(find.textContaining('1 entri baru ditambahkan'), findsOneWidget);
  });

  testWidgets('berkas rusak: pesan ramah, tidak menyimpan apa pun', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Impor data'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bukan json');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Periksa'));
    await tester.pumpAndSettle();

    expect(find.text('Berkas tidak bisa dipakai'), findsOneWidget);
    expect(progress.entries, isEmpty);
  });
}
