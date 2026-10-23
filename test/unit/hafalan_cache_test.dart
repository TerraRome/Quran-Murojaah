import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/progress/activity_entry.dart';
import 'package:quran/Quran/murojaah/progress/activity_store.dart';
import 'package:quran/Quran/murojaah/progress/progress_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'peta dihitung sekali lalu dipakai ulang, dihitung ulang saat log berubah',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = MurojaahProgressController(
        store: MemoryActivityStore(),
      );
      await controller.load();
      var calls = 0;
      controller.verseCount = (surah) {
        calls++;
        return surah == 1 ? 2 : 0;
      };

      final first = controller.hafalan;
      expect(controller.hafalan, same(first), reason: 'hasil di-cache');
      expect(calls, 114, reason: '114 surah, sekali jalan');

      await controller.recordVerses(
        type: ActivityType.murojaah,
        surahNumber: 1,
        verses: const [1, 2],
        at: DateTime(2026, 10, 22, 9),
      );

      final second = controller.hafalan;
      expect(second, isNot(same(first)), reason: 'log berubah → hitung ulang');
      expect(second.of(1).versesCovered, 2);
      expect(calls, 228);
    },
  );
}
