import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/shalat/application/adzan_notifications.dart';
import 'package:quran/Quran/shalat/domain/entities/waktu_shalat.dart';

/// Scheduler palsu: tidak ada plugin, tidak ada perangkat.
class _FakeScheduler implements AdzanScheduler {
  _FakeScheduler({
    this.permission = true,
    this.exact = true,
    this.failOnName,
    this.throwOnCanScheduleExact = false,
  });

  bool permission;
  bool exact;
  String? failOnName;
  bool throwOnCanScheduleExact;

  int cancels = 0;
  final List<({int id, String title, bool exact, DateTime at})> scheduled = [];

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<bool> canScheduleExact() async {
    if (throwOnCanScheduleExact) throw StateError('plugin mati');
    return exact;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required bool exact,
  }) async {
    if (failOnName != null && title.contains(failOnName!)) {
      throw PlatformExceptionLike('exact_alarms_not_permitted');
    }
    scheduled.add((id: id, title: title, exact: exact, at: at));
  }

  @override
  Future<void> cancel() async {
    cancels++;
    scheduled.clear();
  }
}

/// Meniru PlatformException tanpa mengimpor services di test murni.
class PlatformExceptionLike implements Exception {
  PlatformExceptionLike(this.code);
  final String code;
  @override
  String toString() => 'PlatformException($code)';
}

void main() {
  final now = DateTime(2026, 10, 23, 9);

  List<ShalatEntry> times() => [
    ShalatEntry('Subuh', '04:30', DateTime(2026, 10, 23, 4, 30)),
    ShalatEntry('Terbit', '05:45', DateTime(2026, 10, 23, 5, 45)),
    ShalatEntry('Dzuhur', '11:50', DateTime(2026, 10, 23, 11, 50)),
    ShalatEntry('Ashar', '15:10', DateTime(2026, 10, 23, 15, 10)),
    ShalatEntry('Maghrib', '17:55', DateTime(2026, 10, 23, 17, 55)),
    ShalatEntry('Isya', '19:05', DateTime(2026, 10, 23, 19, 5)),
  ];

  AdzanNotifications build(_FakeScheduler scheduler) =>
      AdzanNotifications(scheduler, clock: () => now);

  test('waktu yang belum lewat dipasang, Terbit dilewati', () async {
    final scheduler = _FakeScheduler();
    final result = await build(scheduler).enable(
      times: times(),
      kabkota: 'Bandung',
    );

    expect(result.ok, isTrue);
    expect(result.inexact, isFalse);
    expect(scheduler.scheduled.map((s) => s.title), [
      'Waktu Dzuhur',
      'Waktu Ashar',
      'Waktu Maghrib',
      'Waktu Isya',
    ]);
    expect(scheduler.scheduled.every((s) => s.exact), isTrue);
  });

  test('tanpa izin alarm eksak: tetap terjadwal, tidak eksak, ada pesan', () async {
    final scheduler = _FakeScheduler(exact: false);
    final result = await build(scheduler).enable(
      times: times(),
      kabkota: 'Bandung',
    );

    expect(result.ok, isTrue);
    expect(result.inexact, isTrue);
    expect(result.message, contains('beberapa menit'));
    expect(scheduler.scheduled, isNotEmpty);
    expect(scheduler.scheduled.every((s) => s.exact), isFalse);
  });

  test('cek alarm eksak melempar: jatuh ke tidak eksak, bukan crash', () async {
    final scheduler = _FakeScheduler(throwOnCanScheduleExact: true);
    final result = await build(scheduler).enable(
      times: times(),
      kabkota: 'Bandung',
    );

    expect(result.ok, isTrue);
    expect(result.inexact, isTrue);
    expect(scheduler.scheduled, isNotEmpty);
  });

  test('plugin gagal saat menjadwalkan: pesan ramah, jadwal dibatalkan', () async {
    final scheduler = _FakeScheduler(failOnName: 'Ashar');
    final result = await build(scheduler).enable(
      times: times(),
      kabkota: 'Bandung',
    );

    expect(result.ok, isFalse);
    expect(result.message, contains('tidak bisa dipasang'));
    expect(result.message, isNot(contains('PlatformException')));
    expect(scheduler.scheduled, isEmpty);
    expect(scheduler.cancels, greaterThan(0));
  });

  test('izin ditolak saat saklar dinyalakan: tidak ada jadwal, pesan jelas', () async {
    final scheduler = _FakeScheduler(permission: false);
    final result = await build(scheduler).enable(
      times: times(),
      kabkota: 'Bandung',
      askPermission: true,
    );

    expect(result.ok, isFalse);
    expect(result.message, contains('Izin notifikasi'));
    expect(scheduler.scheduled, isEmpty);
  });

  test('penyegaran otomatis tidak meminta izin', () async {
    final scheduler = _FakeScheduler(permission: false);
    final result = await build(scheduler).enable(
      times: times(),
      kabkota: 'Bandung',
    );

    expect(result.ok, isTrue);
    expect(scheduler.scheduled, isNotEmpty);
  });

  test('semua waktu sudah lewat: tidak ada jadwal, pesan ramah', () async {
    final scheduler = _FakeScheduler();
    final result = await AdzanNotifications(
      scheduler,
      clock: () => DateTime(2026, 10, 23, 23),
    ).enable(times: times(), kabkota: 'Bandung');

    expect(result.ok, isFalse);
    expect(result.message, contains('Tidak ada waktu shalat'));
  });
}
