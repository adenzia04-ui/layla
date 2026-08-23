import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'mihrab_arch.dart';
import 'ornament_backdrop.dart';

/// Shown instead of the app when Firebase could not start.
///
/// Without this, a missing `firebase_options.dart` is a black screen and a
/// stack trace in the console — which tells a developer nothing on a phone,
/// where the console is not in front of them. This says what is wrong and
/// exactly which command fixes it.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Layla — setup required',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _SetupScreen(error: error),
    );
  }
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen({required this.error});

  final Object error;

  static const List<({String step, String detail})> _steps =
      <({String step, String detail})>[
    (
      step: 'Create a Firebase project',
      detail: 'console.firebase.google.com → Add project. Then enable '
          'Authentication (Email/Password + Anonymous), Firestore, and Storage.'
    ),
    (
      step: 'Connect it to this app',
      detail: 'flutterfire configure --platforms=ios,android'
    ),
    (
      step: 'Run again',
      detail: 'flutter run'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.nightSky),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OrnamentBackdrop(height: 220, opacity: 0.1),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: Insets.xl),
                  const SizedBox(
                    height: 96,
                    width: 74,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        MihrabOutline(strokeWidth: 1.2),
                        Icon(
                          Icons.settings_suggest_outlined,
                          color: AppColors.goldSoft,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  Text('Almost there', style: AppType.displayLg),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Layla built and launched correctly — it just has no '
                    'Firebase project to talk to yet. Three steps:',
                    style: AppType.body
                        .copyWith(color: AppColors.mist, height: 1.55),
                  ),
                  const SizedBox(height: Insets.xl),
                  for (int i = 0; i < _steps.length; i++)
                    _StepCard(index: i + 1, data: _steps[i]),
                  const SizedBox(height: Insets.lg),
                  ExpansionTile(
                    title: Text(
                      'Technical details',
                      style: AppType.titleSm.copyWith(color: AppColors.mist),
                    ),
                    iconColor: AppColors.mist,
                    collapsedIconColor: AppColors.mistFaint,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: Insets.lg),
                    children: <Widget>[
                      SelectableText(
                        '$error',
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xl),
                  Text(
                    'Full walkthrough: docs/FIREBASE_SETUP.md',
                    style: AppType.bodySm.copyWith(color: AppColors.goldDim),
                  ),
                  const SizedBox(height: Insets.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.data});

  final int index;
  final ({String step, String detail}) data;

  /// The middle step is a command, so it gets monospace and a copy button.
  bool get _isCommand => data.detail.startsWith('flutter');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.navyElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.navyLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 26,
            width: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: AppType.titleSm.copyWith(color: AppColors.gold),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(data.step, style: AppType.titleSm),
                const SizedBox(height: 4),
                Text(
                  data.detail,
                  style: AppType.bodySm.copyWith(
                    color: AppColors.mistFaint,
                    height: 1.45,
                    fontFamily: _isCommand ? 'Menlo' : null,
                  ),
                ),
              ],
            ),
          ),
          if (_isCommand)
            IconButton(
              tooltip: 'Copy command',
              iconSize: 18,
              color: AppColors.mist,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: data.detail));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Command copied')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
