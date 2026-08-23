import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Noor is a night-first app: the dark theme is the design, and the light
/// theme exists for the white auth/story sheets that sit on top of it.
abstract final class AppTheme {
  static ThemeData get dark {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.midnight,
      secondary: AppColors.goldSoft,
      onSecondary: AppColors.midnight,
      surface: AppColors.navy,
      onSurface: AppColors.cream,
      surfaceContainerHighest: AppColors.navyElevated,
      outline: AppColors.navyLine,
      error: AppColors.rose,
      onError: AppColors.cream,
    );
    return _base(scheme, AppColors.midnight, Brightness.light);
  }

  static ThemeData get light {
    const ColorScheme scheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.bone,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      surface: AppColors.bone,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.boneMuted,
      outline: Color(0xFFDCD4C7),
      error: AppColors.rose,
      onError: AppColors.bone,
    );
    return _base(scheme, AppColors.bone, Brightness.dark);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Color scaffold,
    Brightness statusIcons,
  ) {
    final TextTheme text = AppType.themeFor(scheme.onSurface);
    final bool isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: scheme.onSurface),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusIcons,
          statusBarBrightness: scheme.brightness,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: isDark ? 0.6 : 1),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(56),
          textStyle: AppType.button,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.fromHeight(56),
          textStyle: AppType.button,
          side: BorderSide(color: scheme.outline),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.goldSoft : AppColors.ink,
          textStyle: AppType.titleSm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.navyElevated.withValues(alpha: 0.7)
            : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.lg,
        ),
        hintStyle: AppType.body.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.4),
        ),
        labelStyle: AppType.bodySm.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.7),
        ),
        border: _fieldBorder(scheme.outline),
        enabledBorder: _fieldBorder(scheme.outline),
        focusedBorder: _fieldBorder(scheme.secondary, width: 1.6),
        errorBorder: _fieldBorder(scheme.error),
        focusedErrorBorder: _fieldBorder(scheme.error, width: 1.6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.sheet),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navyElevated,
        contentTextStyle: AppType.bodySm.copyWith(color: AppColors.cream),
        shape: const RoundedRectangleBorder(borderRadius: Radii.card),
        insetPadding: const EdgeInsets.all(Insets.lg),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
        linearTrackColor: AppColors.navyLine,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
        borderSide: BorderSide(color: color, width: width),
      );
}
