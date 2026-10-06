/// `app_version.php` — whether this build should update.
///
/// The server compares integer **build numbers** (the `7` in `1.2.0+7`),
/// never version strings, and the app only acts on its answer.
enum UpdateKind { none, optional, required }

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.kind,
    this.latestVersion,
    this.latestBuild,
    this.minBuild,
    this.storeUrl,
    this.title,
    this.message,
    this.notes = const [],
  });

  final UpdateKind kind;
  final String? latestVersion;
  final int? latestBuild;
  final int? minBuild;
  final String? storeUrl;

  /// Null when [kind] is none.
  final String? title;
  final String? message;

  /// "What's new" lines; may be empty.
  final List<String> notes;

  /// Something the app should prompt for. Without a store link there is
  /// nowhere to send the user, so that also counts as nothing to do.
  bool get actionable =>
      kind != UpdateKind.none && (storeUrl?.trim().isNotEmpty ?? false);

  static int? _int(Object? v) =>
      v == null ? null : (v is int ? v : int.tryParse('$v'));

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory AppUpdateInfo.fromJson(Map<String, dynamic> j) {
    final notes = j['notes'];
    return AppUpdateInfo(
      kind: switch (j['update']) {
        'required' => UpdateKind.required,
        'optional' => UpdateKind.optional,
        _ => UpdateKind.none,
      },
      latestVersion: _str(j['latest_version']),
      latestBuild: _int(j['latest_build']),
      minBuild: _int(j['min_build']),
      storeUrl: _str(j['store_url']),
      title: _str(j['title']),
      message: _str(j['message']),
      notes: notes is List
          ? notes.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
          : const [],
    );
  }
}
