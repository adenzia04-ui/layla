import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class NoorApp extends ConsumerWidget {
  const NoorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    // A prayer window opening no longer seizes the screen.
    //
    // It used to jump straight to /focus, which meant the app took the phone
    // over mid-sentence — while someone was reading, mid-message, mid-anything
    // — and the only way out was to answer it. Blocking the *other* apps is
    // the feature; commandeering Layla Pro was collateral. The same three choices
    // now sit on the home screen, and the banner above the tab bar keeps them
    // one tap away from anywhere.

    return MaterialApp.router(
      title: 'Layla Pro',
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
