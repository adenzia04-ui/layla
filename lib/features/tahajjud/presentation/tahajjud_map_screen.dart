import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/tahajjud_controller.dart';
import '../domain/tahajjud_presence.dart';

/// The live map. Every marker is a **geohash cell**, not a person — see
/// `core/utils/geohash.dart` for why, and `map_consent_sheet.dart` for what
/// the user was told before joining.
class TahajjudMapScreen extends ConsumerStatefulWidget {
  const TahajjudMapScreen({super.key});

  @override
  ConsumerState<TahajjudMapScreen> createState() => _TahajjudMapScreenState();
}

class _TahajjudMapScreenState extends ConsumerState<TahajjudMapScreen> {
  final MapController _map = MapController();

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _centreOnMe(List<PresenceCluster> clusters) {
    for (final PresenceCluster cluster in clusters) {
      if (cluster.includesMe) {
        _map.move(LatLng(cluster.lat, cluster.lng), 8);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PresenceCluster>> clusters =
        ref.watch(presenceClustersProvider);
    final int total = ref.watch(tahajjudLiveCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        children: <Widget>[
          clusters.when(
            loading: () => const LoadingView(message: 'Finding believers…'),
            error: (Object error, StackTrace stack) => ErrorView(
              message: 'The live map could not load.',
              onRetry: () => ref.invalidate(tahajjudPresenceProvider),
            ),
            data: (List<PresenceCluster> list) => FlutterMap(
              mapController: _map,
              options: const MapOptions(
                initialCenter: LatLng(21.4225, 39.8262), // the Kaaba
                initialZoom: 2.4,
                minZoom: 1.6,
                maxZoom: 9, // deliberately capped: no street-level detail
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.flingAnimation,
                ),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const <String>['a', 'b', 'c'],
                  userAgentPackageName: 'com.noorapp.noor',
                  retinaMode: RetinaMode.isHighDensity(context),
                ),
                MarkerLayer(
                  markers: <Marker>[
                    for (final PresenceCluster c in list)
                      Marker(
                        point: LatLng(c.lat, c.lng),
                        width: 58,
                        height: 58,
                        child: _ClusterMarker(cluster: c),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _MapHeader(total: total),
          Positioned(
            left: Insets.lg,
            right: Insets.lg,
            bottom: Insets.lg,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (clusters.hasValue &&
                      clusters.requireValue
                          .any((PresenceCluster c) => c.includesMe))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: FloatingActionButton.small(
                        heroTag: 'centre-me',
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.midnight,
                        onPressed: () => _centreOnMe(clusters.requireValue),
                        child: const Icon(Icons.my_location_rounded),
                      ),
                    ),
                  const _PrivacyFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Row(
          children: <Widget>[
            CircleIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: () => context.pop(),
              background: AppColors.navy.withValues(alpha: 0.9),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.92),
                  borderRadius: Radii.chip,
                  border: Border.all(color: AppColors.navyLine),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        total == 0
                            ? 'Nobody is praying right now'
                            : total == 1
                                ? '1 believer praying Tahajjud'
                                : '$total believers praying Tahajjud',
                        style: AppType.titleSm.copyWith(color: AppColors.cream),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.cluster});

  final PresenceCluster cluster;

  @override
  Widget build(BuildContext context) {
    final bool mine = cluster.includesMe;
    final double size = (26 + cluster.count.clamp(0, 20) * 1.4).toDouble();
    return Center(
      child: Container(
        height: size,
        width: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (mine ? AppColors.emerald : AppColors.gold)
              .withValues(alpha: 0.24),
          border: Border.all(
            color: mine ? AppColors.emerald : AppColors.gold,
            width: mine ? 2 : 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (mine ? AppColors.emerald : AppColors.gold)
                  .withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          '${cluster.count}',
          style: AppType.numeral.copyWith(
            fontSize: 12,
            color: AppColors.cream,
          ),
        ),
      ),
    );
  }
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.navyLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.shield_outlined,
                  size: 15, color: AppColors.goldDim,),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Each circle is a ~5 km area, not a person. Exact locations '
                  'are never shared.',
                  style: AppType.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.mistFaint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '© OpenStreetMap contributors · © CARTO',
            style: AppType.bodySm.copyWith(
              fontSize: 9,
              color: AppColors.mistFaint.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
