import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/recitation_cache.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../application/quran_downloads.dart';
import '../application/quran_prefs.dart';
import '../domain/quran_data.dart';
import '../domain/reciters.dart';

/// Everything kept on the phone for offline listening, by voice, with the
/// room it takes and a way to let it go.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Quran> quran = ref.watch(quranProvider);
    // Drop any download whose files have gone, once the frame is up — not
    // during it, which Riverpod (rightly) refuses.
    if (quran.valueOrNull case final Quran q) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(downloadsProvider.notifier).prune(q),
      );
    }
    final Set<String> keys = ref.watch(downloadsProvider);
    final Map<String, DownloadProgress> running = ref.watch(
      downloadQueueProvider,
    );
    final RecitationCache? cache = RecitationCache.instance;

    return NightScaffold(
      title: 'Downloads',
      leading: BackButton(
        color: AppColors.cream,
        onPressed: () => context.pop(),
      ),
      showOrnaments: false,
      scrollable: true,
      child: quran.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Text('$e', style: AppType.bodySm),
        data: (Quran q) {
          final List<SurahDownload> items =
              keys
                  .map(SurahDownload.parse)
                  .whereType<SurahDownload>()
                  .where(
                    (SurahDownload d) =>
                        ref.read(downloadsProvider.notifier).verify(d, q),
                  )
                  .toList()
                ..sort(
                  (SurahDownload a, SurahDownload b) =>
                      a.reciterId != b.reciterId
                      ? a.reciterId.compareTo(b.reciterId)
                      : a.surah - b.surah,
                );
          int total = 0;
          for (final SurahDownload d in items) {
            total +=
                cache?.sizeOf(
                  reciterById(
                    d.reciterId,
                  ).filesFor(d.surah, q.surah(d.surah).ayahCount),
                ) ??
                0;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.md),
              Text(
                items.isEmpty && running.isEmpty
                    ? 'Nothing downloaded yet. Open a surah, press the tune '
                          'icon by the player, and download it in the voice '
                          'you want — it will play with no signal after that.'
                    : '${items.length} surah${items.length == 1 ? '' : 's'} '
                          'on this phone · ${formatBytes(total)}',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: Insets.lg),
              for (final MapEntry<String, DownloadProgress> e
                  in running.entries)
                if (SurahDownload.parse(e.key) case final SurahDownload d)
                  _Row(
                    title: q.surah(d.surah).name,
                    line:
                        '${reciterById(d.reciterId).name} · '
                        '${e.value.done} of ${e.value.total} files',
                    icon: Icons.downloading_rounded,
                    color: AppColors.gold,
                    progress: e.value.fraction,
                    onOpen: () => context.push(Routes.quranSurah(d.surah)),
                    onRemove: () =>
                        ref.read(downloadQueueProvider.notifier).cancel(d),
                    removeLabel: 'Cancel',
                  ),
              for (final SurahDownload d in items)
                _Row(
                  title: q.surah(d.surah).name,
                  line:
                      '${reciterById(d.reciterId).name} · '
                      '${formatBytes(cache?.sizeOf(reciterById(d.reciterId).filesFor(d.surah, q.surah(d.surah).ayahCount)) ?? 0)}',
                  icon: Icons.offline_pin_rounded,
                  color: AppColors.emerald,
                  onOpen: () => context.push(Routes.quranSurah(d.surah)),
                  onRemove: () =>
                      ref.read(downloadsProvider.notifier).remove(d, q),
                  removeLabel: 'Remove',
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.line,
    required this.icon,
    required this.color,
    required this.onOpen,
    required this.onRemove,
    required this.removeLabel,
    this.progress,
  });

  final String title;
  final String line;
  final IconData icon;
  final Color color;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final String removeLabel;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: NightCard(
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.md,
          Insets.sm,
          Insets.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: color, size: 22),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppType.titleSm),
                      Text(
                        line,
                        style: AppType.bodySm.copyWith(
                          fontSize: 12,
                          color: AppColors.mistFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: removeLabel == 'Remove'
                        ? AppColors.rose
                        : AppColors.mist,
                  ),
                  child: Text(removeLabel),
                ),
              ],
            ),
            if (progress != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              ClipRRect(
                borderRadius: Radii.chip,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  color: AppColors.gold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
