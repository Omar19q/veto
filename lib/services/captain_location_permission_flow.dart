import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/strings.dart';

/// The user starts tracking explicitly while the captain screen is visible.
/// Never solicit the Android Always/Background location permission.
class CaptainLocationPermissionFlow {
  static Future<bool> request(BuildContext context, {bool explainAlways = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.captainLocationServiceRequired)),
        );
      }
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever && context.mounted && explainAlways) {
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.strings.captainLocationPermissionTitle),
          content: Text(dialogContext.strings.captainLocationPermissionBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(dialogContext.strings.captainLocationLater)),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(dialogContext.strings.settings)),
          ],
        ),
      );
      if (goToSettings == true) await Geolocator.openAppSettings();
      permission = await Geolocator.checkPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
