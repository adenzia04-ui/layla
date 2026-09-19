import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../data/prayer_lock_platform.dart';

/// Which apps the prayer focus covers.
///
/// This screen is the reason the Android prayer focus never did anything. The
/// service only ever covers an app that is in the chosen set — quite rightly,
/// since a focus that covered the phone dialler would be a disaster — and on
/// Android there was no way to choose. The native side could list the
/// installed apps and store a set, and the Dart side could call it, and
/// nothing anywhere called the Dart side. So the set was empty on every
/// Android phone, for ever, and the feature could be switched on, granted
/// both permissions, and still do nothing at all.
///
/// iPhone has no equivalent screen because Apple will not allow one: Screen
/// Time hands back opaque tokens through its own picker and never tells the
/// app which apps were chosen.
class PausedAppsScreen extends ConsumerStatefulWidget {
  const PausedAppsScreen({super.key});

  @override
  ConsumerState<PausedAppsScreen> createState() => _PausedAppsScreenState();
}

class _PausedAppsScreenState extends ConsumerState<PausedAppsScreen> {
  List<AndroidApp>? _apps;
  Set<String> _chosen = <String>{};
  String? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final PrayerLockPlatform platform = ref.read(prayerLockPlatformProvider);
    if (platform is! AndroidSoftLock) {
      setState(() => _failure = 'This phone has no app picker.');
      return;
    }
    try {
      final List<AndroidApp> apps = await platform.installedApps();
      final Set<String> chosen = await platform.blockedPackages();
      if (!mounted) return;
      setState(() {
        // Ones already chosen first, then everything else by name, so a list
        // that is dozens long still opens on the part you came to change.
        apps.sort((AndroidApp a, AndroidApp b) {
          final bool ac = chosen.contains(a.package);
          final bool bc = chosen.contains(b.package);
          if (ac != bc) return ac ? -1 : 1;
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
        _apps = apps;
        _chosen = chosen;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _failure = 'The list of apps could not be read.');
    }
  }

  Future<void> _toggle(AndroidApp app, bool on) async {
    final Set<String> next = <String>{..._chosen};
    on ? next.add(app.package) : next.remove(app.package);
    setState(() => _chosen = next);
    // Saved on every tap rather than behind a Done button: there is nothing
    // to review here, and a choice that is lost by pressing Back is the kind
    // of thing nobody reports and everybody resents.
    final PrayerLockPlatform platform = ref.read(prayerLockPlatformProvider);
    if (platform is AndroidSoftLock) await platform.setBlockedPackages(next);
  }

  @override
  Widget build(BuildContext context) {
    final List<AndroidApp>? apps = _apps;

    return NightScaffold(
      title: 'Apps to pause',
      padding: EdgeInsets.zero,
      child: _failure != null
          ? _Centred(text: _failure!)
          : apps == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: Insets.xxl),
              itemCount: apps.length + 1,
              itemBuilder: (BuildContext context, int i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.md,
                      Insets.lg,
                      Insets.lg,
                    ),
                    child: Text(
                      _chosen.isEmpty
                          ? 'Nothing is chosen, so the prayer focus has '
                                'nothing to come back over. Pick the apps that '
                                'take the ten minutes you meant to pray in.'
                          : '${_chosen.length} chosen. During a prayer window, '
                                'opening one of these brings Layla Pro back '
                                'over it.',
                      style: AppType.bodySm.copyWith(
                        color: _chosen.isEmpty
                            ? AppColors.amber
                            : AppColors.mist,
                        height: 1.5,
                      ),
                    ),
                  );
                }
                final AndroidApp app = apps[i - 1];
                return SwitchListTile.adaptive(
                  value: _chosen.contains(app.package),
                  onChanged: (bool on) => _toggle(app, on),
                  activeThumbColor: AppColors.gold,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                  ),
                  secondary: _AppIcon(app: app),
                  title: Text(app.label, style: AppType.titleSm),
                );
              },
            ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});

  final AndroidApp app;

  @override
  Widget build(BuildContext context) {
    final Uint8List? icon = app.icon;
    if (icon == null) {
      return const Icon(Icons.android_rounded, color: AppColors.mist);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(icon, width: 32, height: 32, fit: BoxFit.cover),
    );
  }
}

class _Centred extends StatelessWidget {
  const _Centred({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Insets.xl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppType.bodySm.copyWith(color: AppColors.mist),
      ),
    ),
  );
}
