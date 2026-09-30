import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/recitation_cache.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/quran_downloads.dart';
import '../../domain/quran_data.dart';
import '../../domain/reciters.dart';

/// Keep this surah on the phone, in this voice.
///
/// Three states in one row: not downloaded (a button), downloading (a bar
/// and a count), downloaded (a tick and the size, with remove). No limit
/// on how many: someone spending a week without Wi-Fi needs what they need.
class DownloadRow extends ConsumerWidget {
  const DownloadRow({
    super.key,
    required this.quran,
    required this.surah,
    required this.reciter,
    this.compact = false,
  });

  final Quran quran;
  final int surah;
  final Reciter reciter;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SurahDownload d = SurahDownload(surah: surah, reciterId: reciter.id);
    final Surah s = quran.surah(surah);
    final Downloads downloads = ref.watch(downloadsProvider.notifier);
    final bool done =
        ref.watch(downloadsProvider).contains(d.key) &&
        downloads.verify(d, quran);
    final DownloadProgress? progress = ref.watch(downloadQueueProvider)[d.key];
    final RecitationCache? cache = RecitationCache.instance;

    final Widget trailing;
    final String line;
    if (progress != null) {
      line = '${progress.done} of ${progress.total} files';
      trailing = TextButton(
        onPressed: () => ref.read(downloadQueueProvider.notifier).cancel(d),
        style: TextButton.styleFrom(foregroundColor: AppColors.mist),
        child: const Text('Cancel'),
      );
    } else if (done) {
      final int bytes =
          cache?.sizeOf(reciter.filesFor(surah, s.ayahCount)) ?? 0;
      line = 'On this phone · ${formatBytes(bytes)}';
      trailing = TextButton(
        onPressed: () async {
          unawaited(HapticFeedback.lightImpact());
          await ref.read(downloadsProvider.notifier).remove(d, quran);
        },
        style: TextButton.styleFrom(foregroundColor: AppColors.rose),
        child: const Text('Remove'),
      );
    } else {
      line = reciter.perAyah
          ? '${s.ayahCount} files · listen with no signal'
          : 'One file · listen with no signal';
      trailing = FilledButton.icon(
        onPressed: cache == null
            ? null
            : () {
                unawaited(HapticFeedback.lightImpact());
                unawaited(
                  ref.read(downloadQueueProvider.notifier).start(d, quran),
                );
              },
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.midnight,
          visualDensity: VisualDensity.compact,
          // The app's button theme is full-width; inside a row that is an
          // infinite width, which sinks the whole sheet.
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        ),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Download'),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: compact ? Insets.sm : Insets.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.navyElevated,
        borderRadius: Radii.card,
        border: Border.all(
          color: done
              ? AppColors.emerald.withValues(alpha: 0.5)
              : AppColors.navyLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                done
                    ? Icons.offline_pin_rounded
                    : Icons.cloud_download_outlined,
                size: 22,
                color: done ? AppColors.emerald : AppColors.gold,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${s.name} · ${reciter.name}',
                      style: AppType.titleSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
              const SizedBox(width: Insets.sm),
              trailing,
            ],
          ),
          if (progress != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            ClipRRect(
              borderRadius: Radii.chip,
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 4,
                backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                color: AppColors.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
