import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/data/quran_tokens.dart';
import 'package:quran/Quran/shalat/application/compass_provider.dart';
import 'package:quran/Quran/shalat/presentation/widgets/kiblat_card.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';

/// Kompas palsu: mengirim heading yang sudah ditentukan, atau tidak pernah
/// mengirim apa pun (perangkat tanpa sensor).
class _FakeCompass implements CompassProvider {
  _FakeCompass(this._readings);

  final List<CompassReading>? _readings;

  @override
  Stream<CompassReading> readings() {
    final list = _readings;
    if (list == null) return const Stream.empty();
    return Stream.fromIterable(list);
  }
}

/// Koordinat Jakarta → bearing 295°.
const _jakarta = (latitude: -6.2088, longitude: 106.8456);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    ({double latitude, double longitude})? koordinat = _jakarta,
    CompassProvider? compass,
    bool dark = false,
    VoidCallback? onRetry,
    VoidCallback? onDetectLocation,
  }) async {
    await tester.pumpWidget(
      QuranThemeScope(
        child: MaterialApp(
          theme: QuranTokens.themeData(dark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: KiblatCard(
                koordinat: koordinat,
                dark: dark,
                compass:
                    compass ??
                    _FakeCompass(const [CompassReading(heading: 270)]),
                onRetry: onRetry,
                onDetectLocation: onDetectLocation,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('tanpa koordinat: pesan ramah + dua aksi berikon 48px', (
    tester,
  ) async {
    await pump(tester, koordinat: null);

    expect(find.text('Arah Kiblat'), findsOneWidget);
    expect(
      find.textContaining('Arah kiblat butuh lokasi Anda'),
      findsOneWidget,
    );
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('Gunakan lokasi GPS'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    // Bukan layar error: judul kartu tetap ada.
    expect(find.text('Arah Kiblat'), findsOneWidget);

    for (final label in ['Coba lagi', 'Gunakan lokasi GPS']) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('tanpa koordinat: "Coba lagi" dan "Gunakan lokasi GPS" bekerja', (
    tester,
  ) async {
    var retry = 0;
    var gps = 0;
    await pump(
      tester,
      koordinat: null,
      onRetry: () => retry++,
      onDetectLocation: () => gps++,
    );

    await tester.tap(find.text('Coba lagi'));
    await tester.tap(find.text('Gunakan lokasi GPS'));
    await tester.pump();

    expect(retry, 1);
    expect(gps, 1);
    // Keduanya berikon, bukan tombol teks saja.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Coba lagi'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        matching: find.byIcon(Icons.refresh),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Gunakan lokasi GPS'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        matching: find.byIcon(Icons.my_location),
      ),
      findsOneWidget,
    );
  });

  testWidgets('kompas aktif: derajat kiblat + arahan putar + ikon arah', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Kiblat 295° dari utara'), findsOneWidget);
    // 270 → 295 = putar kanan 25 derajat.
    expect(find.text('Putar ke kanan sekitar 25 derajat.'), findsOneWidget);
    expect(find.byIcon(Icons.rotate_right), findsOneWidget);
    expect(find.textContaining('tidak punya kompas'), findsNothing);
    expect(find.textContaining('Letakkan ponsel mendatar'), findsOneWidget);
  });

  testWidgets('sudah menghadap: ikon centang + teks, bukan hanya warna', (
    tester,
  ) async {
    await pump(
      tester,
      compass: _FakeCompass(const [CompassReading(heading: 297, accuracy: 5)]),
    );

    expect(find.text('Sudah menghadap kiblat.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('kompas tidak akurat: petunjuk kalibrasi', (tester) async {
    await pump(
      tester,
      compass: _FakeCompass(const [CompassReading(heading: 200, accuracy: 30)]),
    );

    expect(
      find.textContaining('Gerakkan perangkat membentuk angka 8'),
      findsOneWidget,
    );
  });

  testWidgets('tanpa sensor: derajat kiblat tetap ada + pesan ramah', (
    tester,
  ) async {
    await pump(tester, compass: _FakeCompass(null));
    await tester.pump(const Duration(seconds: 4));

    expect(find.text('Kiblat 295° dari utara'), findsOneWidget);
    expect(find.textContaining('tidak punya kompas'), findsOneWidget);
    expect(
      find.text('Arahkan perangkat 295 derajat dari utara.'),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('semantics kompas menyebut arah putar', (tester) async {
    await pump(tester);

    final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
    expect(
      semantics.any(
        (s) =>
            s.properties.label ==
            'Kompas kiblat. Putar ke kanan sekitar 25 derajat.',
      ),
      isTrue,
    );
  });

  testWidgets('mode gelap dan terang sama-sama menampilkan teks', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await pump(tester, dark: dark);
      expect(find.text('Kiblat 295° dari utara'), findsOneWidget);
      expect(find.text('Arah Kiblat'), findsOneWidget);
    }
  });

  testWidgets('layar mendatar (rotasi): tanpa overflow, teks tetap ada', (
    tester,
  ) async {
    // Aplikasi tidak mengunci orientasi (tidak ada setPreferredOrientations),
    // jadi tata letak harus aman di lanskap.
    tester.view.physicalSize = const Size(1600, 720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Kiblat 295° dari utara'), findsOneWidget);
    expect(find.textContaining('Letakkan ponsel mendatar'), findsOneWidget);
  });

  testWidgets('teks isi minimal 14px', (tester) async {
    await pump(tester);

    for (final label in [
      'Kiblat 295° dari utara',
      'Putar ke kanan sekitar 25 derajat.',
    ]) {
      final rich = tester.widget<RichText>(
        find.descendant(of: find.text(label), matching: find.byType(RichText)),
      );
      expect(
        rich.text.style?.fontSize,
        greaterThanOrEqualTo(14),
        reason: label,
      );
    }
  });
}
