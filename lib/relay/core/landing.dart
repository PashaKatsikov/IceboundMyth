// Outcome of the boot decision. `RelayCoordinator.decide` returns one
// of the Landing subtypes; the boot screen switches over it and that
// is the only spot a route is actually chosen.

/// Which surface the previous launch ended on. Persisted so a repeat
/// launch can skip most of the pipeline.
enum RouteMemory {
  undecided,
  portal,
  native;

  /// Stored form. Exposed as a getter so callers never lean on `.name`.
  String get wireValue => name;

  /// Tolerant of the labels older builds wrote ('web' / 'game').
  static RouteMemory parse(String? raw) {
    switch (raw) {
      case 'portal':
      case 'web':
        return RouteMemory.portal;
      case 'native':
      case 'game':
        return RouteMemory.native;
      default:
        return RouteMemory.undecided;
    }
  }
}

/// Verdict response, mapped from the wire keys ok / url / expires /
/// message with no renaming.
class Verdict {
  const Verdict({
    required this.approved,
    this.url,
    this.expiresAt,
    this.note,
  });

  factory Verdict.fromJson(Map<String, dynamic> json) {
    final int? expiry = switch (json['expires']) {
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };
    final Object? url = json['url'];
    return Verdict(
      approved: json['ok'] == true,
      url: url is String ? url : null,
      expiresAt: expiry,
      note: json['message']?.toString(),
    );
  }

  factory Verdict.rejected(String note) =>
      Verdict(approved: false, note: note);

  final bool approved;
  final String? url;
  final int? expiresAt;
  final String? note;

  bool get hasDestination => approved && (url?.isNotEmpty ?? false);
}

/// Boot pipeline result. A `switch` over these subtypes cannot silently
/// miss a branch — adding one forces every call site to handle it.
sealed class Landing {
  const Landing();
}

/// Stay in the native game.
final class GameLanding extends Landing {
  const GameLanding();
}

/// Open the WebView at [url]. [coldTap] flags a launch that came from
/// tapping a push while the process was dead — the URL is from the
/// intent payload, not the verdict cache, so the boot art is shortened.
final class PortalLanding extends Landing {
  const PortalLanding(this.url, {this.coldTap = false});

  final String url;
  final bool coldTap;
}

/// Show the no-connection screen. [returnsToGame] is set when the last
/// route was native, letting Retry drop straight back into the game.
final class OfflineLanding extends Landing {
  const OfflineLanding({required this.returnsToGame});

  final bool returnsToGame;
}
