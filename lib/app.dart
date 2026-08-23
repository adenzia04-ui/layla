import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/routing/app_router.dart';
import 'core/routing/routes.dart';
import 'core/theme/app_theme.dart';
import 'features/prayer_lock/application/prayer_lock_controller.dart';
import 'features/prayer_lock/domain/prayer_session.dart';

class NoorApp extends ConsumerWidget {
  const NoorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    // When a prayer window opens while Noor is in the foreground, take the
    // user straight to focus. Only a *new* prayer triggers this — changes in
    // status are handled by the router's redirect, so pressing "I Have Prayed"
    // does not bounce the user off the confirmation screen.
    ref.listen<PrayerSession?>(activeSessionProvider,
        (PrayerSession? previous, PrayerSession? next) {
      if (next == null) return;
      if (previous != null && previous.prayer == next.prayer) return;
      router.go(Routes.focus(next.prayer.key));
    });

    return MaterialApp.router(
      title: 'Layla',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      // Noor is a night-first design; the light theme is used only for the
      // auth sheets, which opt in locally.
      themeMode: ThemeMode.dark,
      builder: (BuildContext context, Widget? child) {
        // Keep type sizes sane: prayer times must stay readable, but a 2×
        // system font would break the compass and the strip.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
