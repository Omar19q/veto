import 'package:flutter/widgets.dart';
import '../../../l10n/strings.dart';

/// Labels only: document IDs and server status values are never translated.
class CaptainApplicationCopy {
  static String document(BuildContext context, String id, String fallback) {
    final l = context.strings;
    return switch (id) {
      'portrait' => l.applicationPortrait,
      'id_front' => l.applicationIdFront,
      'id_back' => l.applicationIdBack,
      'license_front' => l.applicationLicenseFront,
      'license_back' => l.applicationLicenseBack,
      'vehicle_front' => l.applicationVehicleFront,
      'vehicle_back' => l.applicationVehicleBack,
      _ => fallback,
    };
  }
  static String status(BuildContext context, String id) {
    final l = context.strings;
    return switch (id) {
      'pending' => l.applicationPending,
      'needs_info' => l.applicationNeedsInfo,
      'approved' => l.applicationApproved,
      'rejected' => l.applicationRejected,
      _ => id,
    };
  }
}
