import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mushaf_pages.dart';
import '../domain/quran_data.dart';

/// The mushaf pages on this phone: how many, and a download in progress.
class MushafPagesState {
  const MushafPagesState({
    required this.bundled,
    required this.onPhone,
    required this.bytes,
    this.done,
  });

  final bool bundled;
  final int onPhone;
  final int bytes;

  /// Pages fetched so far while "download all" runs; null when idle.
  final int? done;

  bool get complete => bundled || onPhone == Quran.pageCount;
  bool get running => done != null;
}

final NotifierProvider<MushafDownload, MushafPagesState>
mushafDownloadProvider = NotifierProvider<MushafDownload, MushafPagesState>(
  MushafDownload.new,
);

class MushafDownload extends Notifier<MushafPagesState> {
  bool _cancel = false;

  MushafPages get _pages => MushafPages.instance;

  MushafPagesState _read({int? done}) => MushafPagesState(
    bundled: _pages.bundled,
    onPhone: _pages.onPhone,
    bytes: _pages.bytesOnPhone,
    done: done,
  );

  @override
  MushafPagesState build() => _read();

  void refresh() {
    if (!state.running) state = _read();
  }

  Future<bool> start() async {
    if (state.running || state.complete) return state.complete;
    _cancel = false;
    state = _read(done: _pages.onPhone);
    final bool ok = await _pages.downloadAll(
      onProgress: (int done, int _) => state = MushafPagesState(
        bundled: false,
        onPhone: state.onPhone,
        bytes: state.bytes,
        done: done,
      ),
      cancelled: () => _cancel,
    );
    state = _read();
    return ok;
  }

  void cancel() => _cancel = true;

  Future<void> remove() async {
    await _pages.removeAll();
    state = _read();
  }
}
