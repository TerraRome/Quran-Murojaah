/// murojaah_page_shell.dart
///
/// Thin [StatefulWidget] that owns the [MurojaahRecitationSession] lifecycle
/// for the quran-murojaah-surah route.
///
/// Responsibility:
///   - Constructs the session in [initState] via [buildMurojaahSession].
///   - Passes the session to [MushafRendererPage].
///   - Stops and disposes the session in [dispose].
///
/// [MushafRendererPage] does NOT own the session — it only calls stop() on
/// its own dispose, which is idempotent. This shell is the single owner that
/// calls dispose().
library murojaah_page_shell;

import 'package:flutter/material.dart';

import '../../../application/quran_dependencies.dart';
import '../../application/murojaah_dependencies.dart';
import '../../application/murojaah_recitation_session.dart';
import 'mushaf_renderer_page.dart';

/// Route-level owner of [MurojaahRecitationSession].
///
/// Insert this widget into the router instead of [MushafRendererPage] directly
/// so that the session is constructed and disposed with the route.
class MurojaahPageShell extends StatefulWidget {
  const MurojaahPageShell({
    required this.surahNumber,
    super.key,
  });

  final int surahNumber;

  @override
  State<MurojaahPageShell> createState() => _MurojaahPageShellState();
}

class _MurojaahPageShellState extends State<MurojaahPageShell> {
  late final MurojaahRecitationSession _session;

  @override
  void initState() {
    super.initState();
    _session = buildMurojaahSession();

    // E1: Pre-warm the ONNX model asynchronously to eliminate the 4644ms
    // cold-load penalty on the user's first recitation.
    // warmUp() is lifecycle-safe: it checks _disposed internally and
    // never throws — failures fall back to lazy loading silently.
    _session.warmUp();
  }

  @override
  void dispose() {
    // stop() releases the microphone. Safe to call even if not started —
    // MurojaahRecitationSession.stop() guards on _started flag (idempotent).
    // MushafRendererPage also calls stop() in its own dispose(), which is fine
    // because the second call is a no-op.
    _session.stop();

    // dispose() releases ONNX session and stream resources.
    // This shell is the sole caller of dispose() on the session.
    _session.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MushafRendererPage(
      surahNumber: widget.surahNumber,
      controller: QuranDependencies.controller,
      recitationSession: _session,
    );
  }
}
