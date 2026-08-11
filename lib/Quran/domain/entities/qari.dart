/// Representasi satu qari (pembaca Al-Quran) dari API equran.id v2.
///
/// 6 qari tersedia dengan ID "01"–"06".
class Qari {
  const Qari({
    required this.id,
    required this.name,
    required this.slug,
  });

  /// ID qari sesuai API equran.id ("01"–"06").
  final String id;

  /// Nama lengkap qari.
  final String name;

  /// Slug untuk URL audio (mis. "Misyari-Rasyid-Al-Afasi").
  final String slug;

  /// Daftar 6 qari yang tersedia di equran.id.
  static const List<Qari> all = [
    Qari(id: '01', name: 'Abdullah Al-Juhany',       slug: 'Abdullah-Al-Juhany'),
    Qari(id: '02', name: 'Abdul Muhsin Al-Qasim',    slug: 'Abdul-Muhsin-Al-Qasim'),
    Qari(id: '03', name: 'Abdurrahman As-Sudais',    slug: 'Abdurrahman-as-Sudais'),
    Qari(id: '04', name: 'Ibrahim Al-Dossari',       slug: 'Ibrahim-Al-Dossari'),
    Qari(id: '05', name: 'Misyary Rasyid Al-Afasy',  slug: 'Misyari-Rasyid-Al-Afasi'),
    Qari(id: '06', name: 'Yasser Al-Dosari',         slug: 'Yasser-Al-Dosari'),
  ];

  /// Default qari: Misyary Rasyid Al-Afasy (paling populer).
  static const Qari defaultQari = Qari(
    id: '05',
    name: 'Misyary Rasyid Al-Afasy',
    slug: 'Misyari-Rasyid-Al-Afasi',
  );

  /// Cari qari berdasarkan ID. Kembalikan default jika tidak ditemukan.
  static Qari fromId(String id) {
    return all.firstWhere((q) => q.id == id, orElse: () => defaultQari);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Qari && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Qari($id, $name)';
}
