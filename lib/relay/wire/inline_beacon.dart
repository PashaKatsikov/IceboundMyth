// Thin one-shot reader over [AlertChannel]'s in-memory cold-boot tap
// URL, giving the coordinator a single place to consume it. Nothing is
// persisted — a leftover disk slot would leak a push URL onto the next
// icon launch.

import 'alert_channel.dart';

class InlineBeacon {
  InlineBeacon._();

  /// Reads and clears the in-memory tap URL. Returns `null` when
  /// this process was not started by a notification tap.
  static String? consume(AlertChannel alerts) => alerts.takeLaunchTapUrl();
}
