import 'dart:math';

/// Jenis aktivitas yang bisa tercatat di log.
enum ActivityType {
  quranRead('quran_read', 'Bacaan Quran'),
  murojaah('murojaah', 'Murojaah'),
  tafsir('tafsir', 'Tafsir'),
  doa('doa', 'Doa');

  const ActivityType(this.wire, this.label);

  /// Nama stabil di JSON — jangan diubah, dipakai data lama.
  final String wire;
  final String label;

  /// Jenis tak dikenal jatuh ke [murojaah]: entri lama tidak punya field ini.
  static ActivityType fromWire(Object? raw) => values.firstWhere(
    (t) => t.wire == raw,
    orElse: () => ActivityType.murojaah,
  );
}

/// Satu kejadian selesai membaca: rentang ayat pada satu surah.
///
/// Log ini adalah **satu-satunya** sumber angka progres. Streak, XP, level, dan
/// cincin harian diturunkan darinya — tidak ada agregat tersimpan terpisah yang
/// bisa melenceng dari riwayat.
class ActivityEntry {
  ActivityEntry({
    String? id,
    required this.at,
    required this.surahNumber,
    required this.fromVerse,
    required this.toVerse,
    this.type = ActivityType.murojaah,
    this.accuracy,
    this.refId,
    this.synced = false,
  }) : id = id ?? _randomId(),
       assert(fromVerse >= 1),
       assert(toVerse >= fromVerse),
       assert(accuracy == null || (accuracy >= 0 && accuracy <= 1));

  /// Identitas stabil entri. Entri lama (tanpa id) memakai id turunan dari isi
  /// entri, sehingga tetap sama setiap kali dimuat tanpa perlu menulis ulang.
  final String id;

  /// Waktu lokal selesai membaca. Disimpan sebagai instan (UTC di JSON) supaya
  /// pergantian zona waktu tidak menggeser urutan kejadian.
  final DateTime at;

  final int surahNumber;
  final int fromVerse;
  final int toVerse;
  final ActivityType type;

  /// Nomor surah palsu untuk entri yang bukan ayat (mis. doa).
  ///
  /// Tidak pernah cocok dengan surah sungguhan, jadi `versesReadIn` dan peta
  /// hafalan tidak tercemar entri doa.
  static const noSurah = 0;

  /// Ketepatan bacaan 0–1, hanya bermakna untuk [ActivityType.murojaah].
  final double? accuracy;

  /// Identitas item non-ayat, mis. id doa untuk [ActivityType.doa].
  ///
  /// Null untuk jenis lain dan untuk entri format lama — id doa dipakai sebagai
  /// kunci dedupe harian karena doa tidak punya nomor ayat.
  final String? refId;

  /// Disiapkan untuk sinkronisasi nanti; belum dipakai.
  final bool synced;

  /// Satuan kredit entri ini: ayat untuk bacaan, 1 untuk doa.
  int get count => surahNumber == noSurah ? 1 : verses;

  /// Jumlah ayat dalam rentang ini.
  int get verses => toVerse - fromVerse + 1;

  /// XP per ayat untuk murojaah.
  static const xpPerVerse = 5;

  /// XP per ayat menurut jenis aktivitas.
  ///
  /// Murojaah 5/ayat, bacaan Quran 2/ayat (= 10 XP per 5 ayat), tafsir 5/ayat,
  /// doa 5 per doa (satu doa = satu "ayat" pada log). Semua angka ada di sini
  /// supaya UI dan test tidak pernah berbeda.
  static const xpPerVerseByType = <ActivityType, int>{
    ActivityType.murojaah: xpPerVerse,
    ActivityType.quranRead: 2,
    ActivityType.tafsir: 5,
    ActivityType.doa: 5,
  };

  /// XP tambahan sekali per surah per hari bila seluruh ayatnya dibaca.
  static const surahCompleteBonusXp = 20;

  int get xpPerVerseForType => xpPerVerseByType[type] ?? xpPerVerse;

  /// Ambang akurasi agar bacaan murojaah memberi XP.
  static const xpAccuracyThreshold = 0.9;

  /// Tanggal kalender **lokal** pengguna (tanpa jam) — dasar streak dan XP.
  ///
  /// Selalu lewat [DateTime.toLocal] supaya entri yang tersimpan dalam UTC
  /// tetap jatuh pada hari yang dialami pengguna.
  DateTime get day {
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Entri ini memenuhi syarat XP: murojaah perlu akurasi ≥ 90%.
  bool get awardsXp =>
      type != ActivityType.murojaah ||
      (accuracy != null && accuracy! >= xpAccuracyThreshold);

  /// XP entri ini bila dihitung sendiri (tanpa aturan per-hari).
  ///
  /// Angka yang dipakai UI selalu berasal dari `ProgressService`, yang juga
  /// menegakkan batas harian dan larangan XP ganda untuk ayat yang sama.
  int get xp => awardsXp ? verses * xpPerVerseForType : 0;

  Map<String, Object?> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'surah': surahNumber,
    'from': fromVerse,
    'to': toVerse,
    'type': type.wire,
    'accuracy': accuracy,
    'refId': refId,
    'synced': synced,
  };

  /// Null bila data rusak. Entri tanpa `id`/`type` tetap diterima (format lama).
  static ActivityEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    final surah = raw['surah'];
    final from = raw['from'];
    final to = raw['to'];
    if (at == null || surah is! int || from is! int || to is! int) return null;
    if (from < 1 || to < from) return null;

    final accuracy = raw['accuracy'];
    if (accuracy != null &&
        (accuracy is! num || accuracy < 0 || accuracy > 1)) {
      return null;
    }

    final type = ActivityType.fromWire(raw['type']);
    final id = raw['id'];
    final synced = raw['synced'];
    final refId = raw['refId'];

    return ActivityEntry(
      id: id is String && id.isNotEmpty
          ? id
          : _legacyId(at, surah, from, to, type),
      at: at,
      surahNumber: surah,
      fromVerse: from,
      toVerse: to,
      type: type,
      accuracy: (accuracy as num?)?.toDouble(),
      refId: refId is String && refId.isNotEmpty ? refId : null,
      synced: synced == true,
    );
  }

  /// Id deterministik untuk entri format lama — stabil tanpa menulis ulang.
  static String _legacyId(
    DateTime at,
    int surah,
    int from,
    int to,
    ActivityType type,
  ) =>
      'legacy-${at.toUtc().microsecondsSinceEpoch}-$surah-$from-$to-${type.wire}';

  static final Random _random = Random.secure();

  static String _randomId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
