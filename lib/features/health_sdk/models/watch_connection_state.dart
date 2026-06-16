enum WatchConnectionStatus {
  /// Recent watch-sourced data found — watch is connected and syncing.
  connected,

  /// No watch-sourced data in the last hour.
  disconnected,

  /// Could not determine status (permissions missing, SDK error, etc.).
  unknown,
}

class WatchConnectionState {
  final WatchConnectionStatus status;

  /// Display name of the detected wearable source (e.g. "Galaxy Watch 6").
  final String? watchName;

  /// Timestamp of the most recent data point received from the watch.
  final DateTime? lastDataAt;

  final DateTime checkedAt;

  const WatchConnectionState({
    required this.status,
    this.watchName,
    this.lastDataAt,
    required this.checkedAt,
  });

  bool get isConnected => status == WatchConnectionStatus.connected;

  String get statusLabel => switch (status) {
        WatchConnectionStatus.connected => 'Connected',
        WatchConnectionStatus.disconnected => 'Not Connected',
        WatchConnectionStatus.unknown => 'Unknown',
      };

  factory WatchConnectionState.initial() => WatchConnectionState(
        status: WatchConnectionStatus.unknown,
        checkedAt: DateTime.now(),
      );

  @override
  String toString() =>
      'WatchConnectionState($status, watch=$watchName, lastData=$lastDataAt)';
}