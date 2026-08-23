import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';

/// What the user agrees to before appearing on the live map.
@immutable
class MapConsent {
  const MapConsent({required this.appearOnMap, required this.anonymous});

  final bool appearOnMap;
  final bool anonymous;
}

Future<MapConsent?> showMapConsentSheet(BuildContext context) {
  return showModalBottomSheet<MapConsent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    builder: (BuildContext context) => const _MapConsentSheet(),
  );
}

class _MapConsentSheet extends StatefulWidget {
  const _MapConsentSheet();

  @override
  State<_MapConsentSheet> createState() => _MapConsentSheetState();
}

class _MapConsentSheetState extends State<_MapConsentSheet> {
  bool _anonymous = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.sm,
          Insets.xl,
          Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Join the live map?', style: AppType.displaySm),
            const SizedBox(height: Insets.sm),
            Text(
              'Knowing others are awake can help. Here is exactly what gets '
              'shared, and what does not.',
              style: AppType.bodySm.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.xl),
            const _ConsentRow(
              icon: Icons.grid_view_rounded,
              positive: true,
              title: 'A rough area, about 5 km across',
              body:
                  'Your position is rounded to a large map square. Nobody sees '
                  'a street, an address, or a pin on your home.',
            ),
            const _ConsentRow(
              icon: Icons.timer_outlined,
              positive: true,
              title: 'For 90 minutes, then gone',
              body:
                  'Your marker disappears when you end the session, and by '
                  'itself after 90 minutes even if the app is closed.',
            ),
            const _ConsentRow(
              icon: Icons.visibility_off_outlined,
              positive: false,
              title: 'Never shared',
              body:
                  'Your exact location, email, photo, streak and prayer history '
                  'stay private.',
            ),
            const SizedBox(height: Insets.sm),
            SwitchListTile.adaptive(
              value: _anonymous,
              onChanged: (bool v) => setState(() => _anonymous = v),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.gold,
              title: Text('Appear without my name', style: AppType.titleSm),
              subtitle: Text(
                'You will show as "A believer".',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
            ),
            const SizedBox(height: Insets.lg),
            PrimaryButton(
              label: 'Show me on the map',
              icon: Icons.public_rounded,
              onPressed: () => Navigator.of(context).pop(
                MapConsent(appearOnMap: true, anonymous: _anonymous),
              ),
            ),
            const SizedBox(height: Insets.sm),
            GhostButton(
              label: 'Log it privately instead',
              onPressed: () => Navigator.of(context).pop(
                const MapConsent(appearOnMap: false, anonymous: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.positive,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 20,
            color: positive ? AppColors.emerald : AppColors.gold,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppType.titleSm),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
