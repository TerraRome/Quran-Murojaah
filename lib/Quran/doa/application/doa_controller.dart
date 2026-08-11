import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/datasources/doa_local_datasource.dart';
import '../data/datasources/doa_remote_datasource.dart';
import '../domain/entities/doa.dart';

// ── State ────────────────────────────────────────────────────────────────────

sealed class DoaState {
  const DoaState();
}

class DoaLoading extends DoaState {
  const DoaLoading();
}

class DoaLoaded extends DoaState {
  const DoaLoaded({
    required this.all,
    required this.filtered,
    required this.grups,
    required this.tags,
    required this.selectedGrup,
    required this.selectedTag,
    required this.query,
    required this.bookmarkedIds,
    this.isOffline = false,
  });

  /// Semua doa (tidak difilter).
  final List<Doa> all;

  /// Doa setelah filter grup + tag + search.
  final List<Doa> filtered;

  /// Semua grup unik dari response (urutan kemunculan).
  final List<String> grups;

  /// Semua tag unik dari response (urutan kemunculan).
  final List<String> tags;

  final String? selectedGrup;
  final String? selectedTag;
  final String query;
  final Set<int> bookmarkedIds;

  /// True jika data diambil dari cache (offline).
  final bool isOffline;

  bool isBookmarked(int id) => bookmarkedIds.contains(id);

  DoaLoaded copyWith({
    List<Doa>? all,
    List<Doa>? filtered,
    List<String>? grups,
    List<String>? tags,
    String? selectedGrup,
    bool clearGrup = false,
    String? selectedTag,
    bool clearTag = false,
    String? query,
    Set<int>? bookmarkedIds,
    bool? isOffline,
  }) => DoaLoaded(
    all: all ?? this.all,
    filtered: filtered ?? this.filtered,
    grups: grups ?? this.grups,
    tags: tags ?? this.tags,
    selectedGrup: clearGrup ? null : selectedGrup ?? this.selectedGrup,
    selectedTag: clearTag ? null : selectedTag ?? this.selectedTag,
    query: query ?? this.query,
    bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
    isOffline: isOffline ?? this.isOffline,
  );
}

class DoaError extends DoaState {
  const DoaError(this.message);
  final String message;
}

// ── Controller ───────────────────────────────────────────────────────────────

/// Controller untuk fitur Doa.
///
/// Strategi load:
/// 1. Cek koneksi internet via connectivity_plus.
/// 2. Jika **online** → fetch dari API → simpan ke cache → tampilkan.
/// 3. Jika **offline** → baca cache SharedPreferences → tampilkan (isOffline=true).
/// 4. Jika offline dan cache kosong → DoaError.
///
/// Filter: grup + tag (AND), search by nama/grup/tag.
/// Bookmark: SharedPreferences, toggle.
class DoaController extends ValueNotifier<DoaState> {
  DoaController({
    required DoaRemoteDataSource remote,
    required DoaLocalDataSource local,
  }) : _remote = remote,
       _local = local,
       super(const DoaLoading());

  final DoaRemoteDataSource _remote;
  final DoaLocalDataSource _local;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    value = const DoaLoading();
    try {
      final isOnline = await _checkConnectivity();
      List<Doa> doas;
      bool isOffline = false;

      if (isOnline) {
        final models = await _remote.getDoas();
        await _local.saveDoas(models);
        doas = models.map((m) => m.toDomain()).toList();
      } else {
        final cached = await _local.getCachedDoas();
        if (cached == null || cached.isEmpty) {
          value = const DoaError(
            'Tidak ada koneksi internet dan belum ada data tersimpan.',
          );
          return;
        }
        doas = cached.map((m) => m.toDomain()).toList();
        isOffline = true;
      }

      final bookmarks = await _local.getBookmarkedIds();
      final grups = _extractGrups(doas);
      final tags = _extractTags(doas);

      value = DoaLoaded(
        all: doas,
        filtered: doas,
        grups: grups,
        tags: tags,
        selectedGrup: null,
        selectedTag: null,
        query: '',
        bookmarkedIds: bookmarks,
        isOffline: isOffline,
      );
    } on DoaApiException catch (e) {
      // API error — fallback ke cache jika ada
      final cached = await _local.getCachedDoas();
      if (cached != null && cached.isNotEmpty) {
        final doas = cached.map((m) => m.toDomain()).toList();
        final bookmarks = await _local.getBookmarkedIds();
        value = DoaLoaded(
          all: doas,
          filtered: doas,
          grups: _extractGrups(doas),
          tags: _extractTags(doas),
          selectedGrup: null,
          selectedTag: null,
          query: '',
          bookmarkedIds: bookmarks,
          isOffline: true,
        );
      } else {
        value = DoaError(e.message);
      }
    } catch (e) {
      value = DoaError('Terjadi kesalahan: $e');
    }
  }

  // ── Filter ────────────────────────────────────────────────────────────────

  /// Set filter grup. Null = hapus filter grup.
  void setGrup(String? grup) {
    final state = value;
    if (state is! DoaLoaded) return;
    final updated = grup == state.selectedGrup
        ? state.copyWith(clearGrup: true)
        : state.copyWith(selectedGrup: grup);
    value = updated.copyWith(filtered: _applyFilters(updated));
  }

  /// Set filter tag. Null = hapus filter tag.
  void setTag(String? tag) {
    final state = value;
    if (state is! DoaLoaded) return;
    final updated = tag == state.selectedTag
        ? state.copyWith(clearTag: true)
        : state.copyWith(selectedTag: tag);
    value = updated.copyWith(filtered: _applyFilters(updated));
  }

  /// Update query search.
  void search(String query) {
    final state = value;
    if (state is! DoaLoaded) return;
    final updated = state.copyWith(query: query);
    value = updated.copyWith(filtered: _applyFilters(updated));
  }

  /// Reset semua filter dan search.
  void clearFilters() {
    final state = value;
    if (state is! DoaLoaded) return;
    final updated = state.copyWith(clearGrup: true, clearTag: true, query: '');
    value = updated.copyWith(filtered: updated.all);
  }

  // ── Bookmark ──────────────────────────────────────────────────────────────

  Future<void> toggleBookmark(int id) async {
    final state = value;
    if (state is! DoaLoaded) return;
    final isNowBookmarked = await _local.toggleBookmark(id);
    final newIds = Set<int>.from(state.bookmarkedIds);
    if (isNowBookmarked) {
      newIds.add(id);
    } else {
      newIds.remove(id);
    }
    value = state.copyWith(bookmarkedIds: newIds);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any(
        (r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet,
      );
    } catch (_) {
      return false;
    }
  }

  List<String> _extractGrups(List<Doa> doas) {
    final seen = <String>{};
    final result = <String>[];
    for (final d in doas) {
      if (d.grup.isNotEmpty && seen.add(d.grup)) {
        result.add(d.grup);
      }
    }
    return result;
  }

  List<String> _extractTags(List<Doa> doas) {
    final seen = <String>{};
    final result = <String>[];
    for (final d in doas) {
      for (final t in d.tag) {
        if (t.isNotEmpty && seen.add(t)) {
          result.add(t);
        }
      }
    }
    return result;
  }

  List<Doa> _applyFilters(DoaLoaded state) {
    var list = state.all;

    if (state.selectedGrup != null) {
      list = list.where((d) => d.grup == state.selectedGrup).toList();
    }

    if (state.selectedTag != null) {
      list = list.where((d) => d.tag.contains(state.selectedTag)).toList();
    }

    if (state.query.isNotEmpty) {
      final q = state.query.toLowerCase();
      list = list
          .where(
            (d) =>
                d.nama.toLowerCase().contains(q) ||
                d.grup.toLowerCase().contains(q) ||
                d.tag.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }

    return list;
  }
}
