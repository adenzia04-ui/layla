import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../application/tafsir_service.dart';
import '../../domain/quran_data.dart';

/// Ibn Kathir on one ayah, in a sheet over the reader.
Future<void> showTafsir(BuildContext context, Ayah ayah, String surahName) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      builder: (BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (BuildContext context, ScrollController controller) =>
            _TafsirBody(
              ayah: ayah,
              surahName: surahName,
              controller: controller,
            ),
      ),
    );

class _TafsirBody extends ConsumerWidget {
  const _TafsirBody({
    required this.ayah,
    required this.surahName,
    required this.controller,
  });

  final Ayah ayah;
  final String surahName;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> tafsir = ref.watch(tafsirProvider(ayah.key));
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.md, Insets.xl, 40),
      children: <Widget>[
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.navyLine,
              borderRadius: Radii.chip,
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        Text(
          'TAFSIR IBN KATHIR · $surahName ${ayah.key}',
          style: AppType.label.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: Insets.md),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            ayah.arabic,
            textAlign: TextAlign.right,
            style: AppType.quran(
              22,
            ).copyWith(color: AppColors.cream, height: 2),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          ayah.translation,
          style: AppType.bodySm.copyWith(color: AppColors.mist, height: 1.5),
        ),
        const Divider(color: AppColors.navyLine, height: Insets.xxl),
        tafsir.when(
          data: (String text) => Text(
            text,
            style: AppType.body.copyWith(color: AppColors.cream, height: 1.65),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(Insets.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, _) => Column(
            children: <Widget>[
              Text(
                'The tafsir could not be fetched. It needs a signal the '
                'first time; after that it is kept on the phone.',
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: Insets.lg),
              GhostButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                expand: false,
                onPressed: () => ref.invalidate(tafsirProvider(ayah.key)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        Text(
          'Abridged English edition, via quran.com.',
          style: AppType.bodySm.copyWith(
            fontSize: 11,
            color: AppColors.mistFaint,
          ),
        ),
      ],
    );
  }
}
