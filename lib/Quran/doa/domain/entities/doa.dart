/// Domain entity untuk satu doa dari API equran.id/api/doa.
class Doa {
  const Doa({
    required this.id,
    required this.grup,
    required this.nama,
    required this.ar,
    required this.tr,
    required this.idn,
    required this.tentang,
    required this.tag,
  });

  final int id;

  /// Kategori/grup doa, e.g. "Doa Harian", "Doa Shalat".
  final String grup;

  /// Nama pendek doa, e.g. "Doa Sebelum Makan".
  final String nama;

  /// Teks Arab.
  final String ar;

  /// Transliterasi Latin.
  final String tr;

  /// Terjemahan Indonesia.
  final String idn;

  /// Penjelasan/konteks doa (bisa kosong).
  final String tentang;

  /// Tag kata kunci, e.g. ["makan", "harian"].
  final List<String> tag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Doa && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
