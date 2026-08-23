
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => const PermissionService());

/// Thin wrapper so screens never import `permission_handler` directly and the
/// "permanently denied → open settings" path is handled in exactly one place.
class PermissionService {
  const PermissionService();

  Future<PermissionOutcome> requestLocation() =>
      _request(Permission.locationWhenInUse);

  Future<PermissionOutcome> requestCamera() => _request(Permission.camera);

  Future<PermissionOutcome> requestNotifications() =>
      _request(Permission.notification);

  Future<bool> get hasLocation => Permission.locationWhenInUse.isGranted;
  Future<bool> get hasCamera => Permission.camera.isGranted;
  Future<bool> get hasNotifications => Permission.notification.isGranted;

  Future<PermissionOutcome> _request(Permission permission) async {
    final PermissionStatus status = await permission.request();
    if (status.isGranted || status.isLimited) return PermissionOutcome.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }

  Future<bool> openSettings() => openAppSettings();
}

enum PermissionOutcome {
  granted,
  denied,

  /// The user must change this in the system Settings app.
  permanentlyDenied;

  bool get isGranted => this == PermissionOutcome.granted;
}
