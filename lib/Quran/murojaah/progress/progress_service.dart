import 'activity_entry.dart';

/// Target harian dalam jumlah ayat.
enum DailyGoal {
  ringan(5, 'Ringan', '5 ayat sehari'),
  sedang(15, 'Sedang', '15 ayat sehari'),
  serius(30, 'Serius', '30 ayat sehari');

  const DailyGoal(this.verses, this.label, this.detail);

  final int verses;
  final String label;
  final String detail;

  static DailyGoal fromVerses(int? verses) => values.firstWhere(
    (g) => g.verses == verses,
    orElse: () => DailyGoal.sedang,
  );
}

/// Progres satu jenis aktivitas pada satu hari.
class ActivityDay {
  const ActivityDay({
    required this.type,
    required this.count,
    required this.done,
  });

  final ActivityType type;

  /// Ayat yang dibaca hari ini; untuk doa berarti jumlah doa.
  final int count;

  /// Memenuhi ambang streak jenis ini ([ProgressService.streakMinByType]).
  final bool done;
}

/// Angka progres yang diturunkan dari log aktivitas.
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.todayVerses,
    required this.goal,
    required this.streak,
    required this.totalXp,
    required this.activeToday,
    this.todayXp = 0,
    this.activities = const {},
  });

  /// Ayat yang dihitung untuk cincin target: murojaah + bacaan Quran saja.
  final int todayVerses;

  final DailyGoal goal;
  final int streak;
  final int totalXp;
  final bool activeToday;
  final int todayXp;

  /// Ringkasan per jenis aktivitas hari ini.
  final Map<ActivityType, ActivityDay> activities;

  ActivityDay activityOf(ActivityType type) =>
      activities[type] ?? ActivityDay(type: type, count: 0, done: false);

  double get goalFraction =>
      (todayVerses / goal.verses).clamp(0.0, 1.0).toDouble();

  bool get goalReached => todayVerses >= goal.verses;

  /// Sisa ayat untuk mencapai target hari ini (0 bila sudah lewat).
  int get remaining => (goal.verses - todayVerses).clamp(0, goal.verses);

  /// Level naik tiap 200 XP; level 1 di awal.
  static const xpPerLevel = 200;

  int get level => totalXp ~/ xpPerLevel + 1;

  /// XP di dalam level berjalan.
  int get xpIntoLevel => totalXp % xpPerLevel;

  double get levelFraction => xpIntoLevel / xpPerLevel;
}

/// Keadaan satu hari untuk baris kalender 7 hari.
class DayActivity {
  const DayActivity({
    required this.day,
    required this.verses,
    required this.active,
    required this.freeRest,
    required this.isToday,
  });

  /// Tanggal lokal (tanpa jam).
  final DateTime day;

  final int verses;

  /// Hari dihitung aktif untuk streak ([ProgressService.streakMinByType]).
  final bool active;

  /// Hari kosong yang dipakai sebagai jatah libur gratis mingguan.
  final bool freeRest;

  final bool isToday;
}

/// Menurunkan seluruh angka progres dari daftar [ActivityEntry].
///
/// Murni: tidak menyentuh penyimpanan, dan satu-satunya sumber "sekarang"
/// adalah parameter [now]. Semua perilaku bisa diuji tanpa menunggu hari
/// berganti atau mengubah jam perangkat.
class ProgressService {
  const ProgressService(this.entries, {this.verseCount});

  final List<ActivityEntry> entries;

  /// Jumlah ayat satu surah, disuntikkan dari daftar surah yang sudah ada.
  ///
  /// Dipakai untuk bonus "satu surah tamat". Null/0 berarti tidak diketahui —
  /// bonus tidak diberikan, bukan ditebak.
  final int Function(int surahNumber)? verseCount;

  /// Batas XP per hari, per jenis aktivitas.
  static const dailyXpCap = <ActivityType, int>{
    ActivityType.murojaah: 150,
    ActivityType.quranRead: 100,
    ActivityType.tafsir: 50,
    ActivityType.doa: 50,
  };

  /// Satu hari libur gratis per minggu kalender (Senin–Minggu).
  static const freeRestDaysPerWeek = 1;

  /// Ayat minimal bacaan Quran agar satu hari dianggap aktif untuk streak.
  static const streakMinVersesPerDay = 1;

  /// Ambang "selesai" per jenis, dalam satuan yang sama dengan [ActivityDay.count]
  /// (ayat, dan jumlah doa untuk [ActivityType.doa]).
  ///
  /// Semua 1: satu ayat tafsir atau satu doa sudah cukup mempertahankan streak.
  static const streakMinByType = <ActivityType, int>{
    ActivityType.murojaah: streakMinVersesPerDay,
    ActivityType.quranRead: streakMinVersesPerDay,
    ActivityType.tafsir: 1,
    ActivityType.doa: 1,
  };

  /// Jenis yang dihitung untuk cincin target harian.
  static const ringTypes = {ActivityType.murojaah, ActivityType.quranRead};

  ProgressSnapshot snapshot({required DateTime now, required DailyGoal goal}) {
    final today = _dayOf(now);
    final ringVerses = _ringVersesByDay();
    final activeDays = _activeDays();
    final xpByDay = _xpByDay();

    return ProgressSnapshot(
      todayVerses: ringVerses[today] ?? 0,
      goal: goal,
      streak: _streak(activeDays, today),
      totalXp: xpByDay.values.fold(0, (a, b) => a + b),
      activeToday: activeDays.contains(today),
      todayXp: xpByDay[today] ?? 0,
      activities: _activitiesOn(today),
    );
  }

  /// Tujuh hari terakhir (paling lama dulu, hari ini paling akhir).
  ///
  /// Dipakai baris kalender: satu sumber kebenaran untuk "hari aktif", "hari
  /// libur gratis", dan "hari ini" — bukan hitungan terpisah di widget.
  List<DayActivity> weeklyDays({required DateTime now, int count = 7}) {
    final today = _dayOf(now);
    final ringVerses = _ringVersesByDay();
    final activeDays = _activeDays();
    final freeDays = _streakInfo(activeDays, today).freeDays;

    return [
      for (var offset = count - 1; offset >= 0; offset--)
        () {
          final day = DateTime(today.year, today.month, today.day - offset);
          return DayActivity(
            day: day,
            verses: ringVerses[day] ?? 0,
            active: activeDays.contains(day),
            freeRest: freeDays.contains(day),
            isToday: day == today,
          );
        }(),
    ];
  }

  /// Entri terakhir untuk [type], atau null bila belum ada.
  ///
  /// Dipakai tombol "Lanjutkan": melanjutkan surah terakhir yang benar-benar
  /// dicatat, bukan menebak dari daftar surah.
  ActivityEntry? lastEntryOf(ActivityType type) {
    ActivityEntry? latest;
    for (final e in entries) {
      if (e.type != type) continue;
      if (latest == null || e.at.isAfter(latest.at)) latest = e;
    }
    return latest;
  }

  /// Ayat yang sudah selesai dibaca pada [surahNumber], dari log.
  ///
  /// Dipakai peta hafalan: ayat dianggap hafal bila pernah masuk rentang
  /// aktivitas, bukan dari status tersimpan terpisah.
  Set<int> versesReadIn(int surahNumber) => {
    for (final e in entries)
      if (e.surahNumber == surahNumber)
        for (var v = e.fromVerse; v <= e.toVerse; v++) v,
  };

  /// Ayat untuk cincin target: hanya [ringTypes]. Tafsir & doa tidak dihitung.
  Map<DateTime, int> _ringVersesByDay() {
    final byDay = <DateTime, int>{};
    for (final e in entries) {
      if (!ringTypes.contains(e.type)) continue;
      byDay.update(e.day, (v) => v + e.verses, ifAbsent: () => e.verses);
    }
    return byDay;
  }

  /// Hari yang memenuhi ambang minimal **jenis apa pun** — dasar streak.
  Set<DateTime> _activeDays() {
    final countByDayType = <String, int>{};
    for (final e in entries) {
      final key = '${e.day.toIso8601String()}|${e.type.wire}';
      countByDayType.update(key, (v) => v + e.count, ifAbsent: () => e.count);
    }
    return {
      for (final entry in countByDayType.entries)
        if (entry.value >=
            (streakMinByType[
                    ActivityType.fromWire(entry.key.split('|').last)
                  ] ??
                  1))
          DateTime.parse(entry.key.split('|').first),
    };
  }

  /// Ringkasan empat jenis aktivitas pada [day].
  Map<ActivityType, ActivityDay> _activitiesOn(DateTime day) {
    final count = <ActivityType, int>{};
    for (final e in entries) {
      if (e.day != day) continue;
      count.update(e.type, (v) => v + e.count, ifAbsent: () => e.count);
    }
    return {
      for (final type in ActivityType.values)
        type: ActivityDay(
          type: type,
          count: count[type] ?? 0,
          done: (count[type] ?? 0) >= (streakMinByType[type] ?? 1),
        ),
    };
  }

  /// XP per hari, setelah aturan akurasi, batas harian, larangan XP ganda, dan
  /// bonus surah tamat.
  ///
  /// Satu ayat hanya memberi XP sekali per hari walau dibaca di beberapa sesi,
  /// dan total per jenis aktivitas dibatasi [dailyXpCap]. Bonus surah dihitung
  /// setelah ayat: entri-entri satu hari untuk satu surah yang bersama-sama
  /// menutup seluruh ayat surah itu memberi [ActivityEntry.surahCompleteBonusXp]
  /// sekali, dan tetap tunduk pada batas harian jenis tersebut.
  Map<DateTime, int> _xpByDay() {
    final ordered = [...entries]..sort((a, b) => a.at.compareTo(b.at));
    final awardedVerses = <String>{};
    final awardedRefs = <String>{};
    final xpByDay = <DateTime, int>{};
    final xpByDayType = <String, int>{};
    final coveredByDaySurah = <String, Set<int>>{};

    void award(DateTime day, ActivityType type, int amount) {
      final dayKey = day.toIso8601String();
      final typeKey = '$dayKey|${type.wire}';
      final cap = dailyXpCap[type] ?? 0;
      final used = xpByDayType[typeKey] ?? 0;
      final room = cap - used;
      if (room <= 0) return;
      final gain = amount < room ? amount : room;
      xpByDayType[typeKey] = used + gain;
      xpByDay[day] = (xpByDay[day] ?? 0) + gain;
    }

    for (final entry in ordered) {
      if (!entry.awardsXp) continue;
      final day = entry.day;
      final dayKey = day.toIso8601String();

      if (entry.surahNumber == ActivityEntry.noSurah) {
        // Bukan ayat (doa): dedupe per refId, satu kredit per hari.
        final refKey = '$dayKey|${entry.type.wire}|${entry.refId ?? entry.id}';
        if (awardedRefs.add(refKey)) {
          award(day, entry.type, entry.xpPerVerseForType);
        }
        continue;
      }

      final covered = entry.type == ActivityType.quranRead
          ? coveredByDaySurah.putIfAbsent(
              '$dayKey|${entry.surahNumber}',
              () => <int>{},
            )
          : null;
      for (var verse = entry.fromVerse; verse <= entry.toVerse; verse++) {
        covered?.add(verse);
        final verseKey = '$dayKey|${entry.surahNumber}|$verse';
        if (!awardedVerses.add(verseKey)) continue;
        award(day, entry.type, entry.xpPerVerseForType);
      }
    }

    // Bonus surah tamat: satu kali per surah per hari, hanya untuk jenis yang
    // memang punya XP per ayat (tafsir/doa tidak).
    for (final entry in coveredByDaySurah.entries) {
      final parts = entry.key.split('|');
      final day = DateTime.parse(parts[0]);
      final surah = int.parse(parts[1]);
      final total = verseCount?.call(surah) ?? 0;
      if (total <= 0 || entry.value.length < total) continue;
      award(day, ActivityType.quranRead, ActivityEntry.surahCompleteBonusXp);
    }
    return xpByDay;
  }

  /// Jumlah hari berurutan yang punya aktivitas, dihitung mundur dari hari ini.
  ///
  /// Hari ini yang masih kosong tidak memutus streak. Hari kosong lain hanya
  /// boleh satu per minggu ([freeRestDaysPerWeek]); hari kosong kedua di minggu
  /// yang sama memutus streak. Streak tidak melihat akurasi maupun target.
  int _streak(Set<DateTime> activeDays, DateTime today) =>
      _streakInfo(activeDays, today).streak;

  /// Jalan mundur satu hari sekali: hasilkan panjang streak sekaligus hari mana
  /// yang dipakai sebagai jatah libur, supaya kalender dan angka streak tidak
  /// pernah berbeda cerita.
  ({int streak, Set<DateTime> freeDays}) _streakInfo(
    Set<DateTime> activeDays,
    DateTime today,
  ) {
    if (activeDays.isEmpty) return (streak: 0, freeDays: const {});

    var cursor = today;
    if (!activeDays.contains(cursor)) {
      cursor = _previousDay(cursor);
      if (!activeDays.contains(cursor)) return (streak: 0, freeDays: const {});
    }

    // Berhenti saat melewati entri paling awal — tidak ada hari lain yang bisa
    // memperpanjang streak.
    final earliest = activeDays.reduce((a, b) => a.isBefore(b) ? a : b);
    final freeUsed = <DateTime, int>{};
    final freeDays = <DateTime>{};
    var streak = 0;

    while (!cursor.isBefore(earliest)) {
      if (activeDays.contains(cursor)) {
        streak++;
        cursor = _previousDay(cursor);
        continue;
      }
      final week = _weekStart(cursor);
      if ((freeUsed[week] ?? 0) >= freeRestDaysPerWeek) break;
      freeUsed[week] = (freeUsed[week] ?? 0) + 1;
      freeDays.add(cursor);
      cursor = _previousDay(cursor);
    }
    return (streak: streak, freeDays: freeDays);
  }

  /// Hari lokal pengguna dari sebuah instan.
  static DateTime _dayOf(DateTime at) {
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _previousDay(DateTime day) =>
      DateTime(day.year, day.month, day.day - 1);

  /// Senin pada minggu kalender yang memuat [day].
  static DateTime _weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));
}
