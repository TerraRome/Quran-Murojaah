import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran/Quran/murojaah/recite/recite_murojaah_service.dart';
import 'package:recite_quran/recite_quran.dart';

void main() {
  test('klien menambah Accept: application/octet-stream (BL-08-1)', () async {
    String? accept;
    final client = AcceptOctetStreamClient(
      MockClient((req) async {
        accept = req.headers['Accept'];
        return http.Response('ok', 200);
      }),
    );

    await client.get(Uri.parse('https://api.github.com/x'));

    expect(accept, 'application/octet-stream');
  });

  test('unduhan model lewat klien ini membawa header dan selesai', () async {
    final seen = <String?>[];
    final body = List<int>.filled(11 * 1024 * 1024, 1);
    final dir = Directory.systemTemp.createTempSync('model_dl_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final ok = await ModelDownloader(
      modelUrl: 'https://api.github.com/x',
      customStoragePath: dir.path,
    ).downloadAssets(
      client: AcceptOctetStreamClient(
        MockClient((req) async {
          seen.add(req.headers['Accept']);
          return http.Response.bytes(body, 200);
        }),
      ),
    );

    expect(ok, isTrue);
    expect(seen, ['application/octet-stream']);
  });
}
