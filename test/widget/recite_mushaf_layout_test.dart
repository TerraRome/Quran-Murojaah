import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/Quran/murojaah/recite/widgets/recite_mushaf.dart';
import 'package:quran/Quran/murojaah/recite/widgets/redaction_geometry.dart';
import 'package:quran/Quran/presentation/widgets/quran_theme_scope.dart';
import 'package:recite_quran/recite_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuranVerse _v(int ayah, String text) => QuranVerse(
      surah: 1,
      ayah: ayah,
      textUthmani: text,
      uthmaniWords: text.split(' '),
      textPhoneme: text,
      phonemeWords: text.split(' '),
      surahName: 'الفاتحة',
      surahNameEn: 'Al-Fatihah',
    );

/// Kotak yang benar-benar digambar: kata tersembunyi + penanda ayat.
typedef Geometry = ({List<Rect> hidden, List<Rect> markers});

/// Ambil geometri nyata dari widget: kotak redaksi diambil dari painter yang
/// dipakai `ReciteMushaf`, penanda diukur dari span penanda ayat.
Geometry _geometry(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find
        .descendant(of: find.byType(ReciteMushaf), matching: find.byType(RichText))
        .first,
  );
  final root = rich.text as TextSpan;
  final spans = root.children!.cast<TextSpan>();

  final markers = <(int, int)>[];
  var offset = 0;
  for (final s in spans) {
    final text = s.text ?? '';
    if (text.contains('۝')) markers.add((offset, offset + text.length));
    offset += text.length;
  }

  final richWidth = tester.getSize(
    find
        .descendant(of: find.byType(ReciteMushaf), matching: find.byType(RichText))
        .first,
  ).width;
  final painter = TextPainter(text: root, textDirection: TextDirection.rtl)
    ..layout(maxWidth: richWidth);

  List<Rect> boxesOf((int, int) r) => [
        for (final b in painter.getBoxesForSelection(
          TextSelection(baseOffset: r.$1, extentOffset: r.$2),
        ))
          Rect.fromLTRB(b.left, b.top, b.right, b.bottom),
      ];

  // Kotak redaksi diambil dari CustomPainter overlay (sumber kebenaran).
  final painters = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(ReciteMushaf),
          matching: find.byType(CustomPaint),
        ),
      )
      .toList();
  final hidden = <Rect>[];
  for (final p in painters) {
    final painterDelegate = p.painter;
    if (painterDelegate != null &&
        painterDelegate.runtimeType.toString().contains('Redaction')) {
      hidden.addAll(_boxesOfPainter(painterDelegate));
    }
  }

  return (
    hidden: hidden,
    markers: [for (final m in markers) ...boxesOf(m)],
  );
}

/// Baca `boxes` dari painter redaksi tanpa membuka kelas privatnya.
List<Rect> _boxesOfPainter(CustomPainter painter) {
  final dynamic dynamicPainter = painter;
  final boxes = dynamicPainter.boxes as List<Rect>;
  return boxes;
}

Future<void> _pump(
  WidgetTester tester, {
  required List<QuranVerse> verses,
  required double width,
  required double textScale,
  required bool dark,
}) async {
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: QuranThemeScope(
          child: Scaffold(
            body: SizedBox(
              width: width,
              height: 1200,
              child: ReciteMushaf(
                verses: verses,
                matched: const {},
                missed: const {},
                activeVerse: 0,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectNoOverlap(Geometry g, String reason) {
  for (var i = 0; i < g.hidden.length; i++) {
    final box = g.hidden[i];
    for (final marker in g.markers) {
      expect(
        box.overlaps(marker),
        isFalse,
        reason: '$reason: kotak $box menimpa penanda $marker',
      );
      // Jarak minimum horizontal bila satu baris.
      final sameLine = box.top < marker.bottom && box.bottom > marker.top;
      if (sameLine) {
        final gap = box.right <= marker.left
            ? marker.left - box.right
            : box.left - marker.right;
        expect(
          gap,
          greaterThanOrEqualTo(kRedactionGap - 0.01),
          reason: '$reason: jarak $gap < $kRedactionGap (kotak $box, penanda $marker)',
        );
      }
    }
    for (var j = i + 1; j < g.hidden.length; j++) {
      final other = g.hidden[j];
      expect(
        box.overlaps(other),
        isFalse,
        reason: '$reason: kotak $box menimpa kotak $other',
      );
      final sameLine = box.top < other.bottom && box.bottom > other.top;
      if (sameLine) {
        final gap = box.right <= other.left
            ? other.left - box.right
            : box.left - other.right;
        expect(
          gap,
          greaterThanOrEqualTo(kRedactionGap - 0.01),
          reason: '$reason: jarak antar kotak $gap < $kRedactionGap',
        );
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Geometri murni ────────────────────────────────────────────────────────

  group('redactionBoxes', () {
    test('kotak dipotong dengan jarak tetap di sekitar penanda', () {
      final boxes = redactionBoxes(
        words: const [
          WordBox(0, Rect.fromLTRB(200, 0, 300, 28)),
          WordBox(1, Rect.fromLTRB(100, 0, 200, 28)),
        ],
        markerBoxes: const [Rect.fromLTRB(180, 0, 220, 28)],
      );
      for (final b in boxes) {
        expect(b.overlaps(const Rect.fromLTRB(180, 0, 220, 28)), isFalse);
      }
      expect(boxes.length, 2);
      // Potongan kanan tidak lebih dekat dari jarak minimum ke penanda.
      final right = boxes.firstWhere((b) => b.left > 220);
      expect(right.left, greaterThanOrEqualTo(220 + kRedactionGap));
    });

    test('kata berurutan di baris sama digabung, baris lain tidak', () {
      final boxes = redactionBoxes(
        words: const [
          WordBox(0, Rect.fromLTRB(200, 0, 300, 28)),
          WordBox(1, Rect.fromLTRB(100, 0, 200, 28)),
          WordBox(2, Rect.fromLTRB(200, 40, 300, 68)),
        ],
        markerBoxes: const [],
      );
      expect(boxes.length, 2);
    });

    test('kata yang tidak berurutan tidak digabung', () {
      final boxes = redactionBoxes(
        words: const [
          WordBox(0, Rect.fromLTRB(200, 0, 300, 28)),
          WordBox(2, Rect.fromLTRB(100, 0, 200, 28)),
        ],
        markerBoxes: const [],
      );
      expect(boxes.length, 2);
    });

    test('kotak tidak keluar batas kata', () {
      const word = Rect.fromLTRB(100, 0, 200, 28);
      final boxes = redactionBoxes(
        words: const [WordBox(0, word)],
        markerBoxes: const [],
      );
      expect(boxes.single.left, greaterThan(word.left));
      expect(boxes.single.right, lessThan(word.right));
      expect(boxes.single.top, greaterThan(word.top));
      expect(boxes.single.bottom, lessThan(word.bottom));
    });

    test('tinggi kotak tidak melebihi tinggi baris', () {
      // Glyph pendek: inset vertikal tidak boleh membuat tinggi negatif.
      final boxes = redactionBoxes(
        words: const [WordBox(0, Rect.fromLTRB(100, 0, 200, 6))],
        markerBoxes: const [],
      );
      expect(boxes.single.height, greaterThan(0));
      expect(boxes.single.height, lessThanOrEqualTo(6));
    });
  });

  // ── Tata letak nyata ──────────────────────────────────────────────────────

  final cases = <String, List<QuranVerse>>{
    'ayat panjang membungkus': [
      _v(1, 'بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم '
          'مالك يوم الدين إياك نعبد وإياك نستعين'),
      _v(2, 'اهدنا الصراط المستقيم'),
    ],
    'ayat satu kata': [_v(1, 'بسم'), _v(2, 'الله')],
    'akhir ayat di ujung baris': [
      _v(1, 'بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم مالك'),
      _v(2, 'يوم الدين'),
    ],
  };

  for (final entry in cases.entries) {
    for (final width in [360.0, 411.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
            '${entry.key} · ${width.toInt()}px · ${scale}x · '
            '${dark ? 'gelap' : 'terang'}',
            (tester) async {
              await _pump(
                tester,
                verses: entry.value,
                width: width,
                textScale: scale,
                dark: dark,
              );
              final g = _geometry(tester);
              expect(g.markers, isNotEmpty, reason: 'penanda ayat harus ada');
              expect(g.hidden, isNotEmpty, reason: 'kotak redaksi harus ada');
              _expectNoOverlap(g, entry.key);
            },
          );
        }
      }
    }
  }
}
