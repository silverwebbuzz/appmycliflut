/// eClinicPro Points & Refer — `store_points.php?action=summary` (doc 12).
///
/// Wording rule (legal): these are **points**, 1 point = ₹1 off a store
/// order. Never call them money, cash, wallet or credit in the UI.
///
/// Every field is optional with a safe default, so the app keeps working
/// against a server where points are off (`enabled: false` and nothing else).
library;

int? _int(Object? v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

String? _str(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) => v is List
    ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList()
    : <T>[];

class PointsBalance {
  const PointsBalance({
    this.available = 0,
    this.pending = 0,
    this.welcome = 0,
    this.standard = 0,
  });

  /// "points ready to use".
  final int available;

  /// "points pending".
  final int pending;
  final int welcome;
  final int standard;

  factory PointsBalance.fromJson(Map<String, dynamic> j) => PointsBalance(
        available: _int(j['available']) ?? 0,
        pending: _int(j['pending']) ?? 0,
        welcome: _int(j['welcome']) ?? 0,
        standard: _int(j['standard']) ?? 0,
      );
}

/// One batch of points.
class PointsLot {
  const PointsLot({
    required this.kind,
    required this.status,
    this.points = 0,
    this.note,
    this.availableAt,
    this.expiresAt,
  });

  /// `welcome` · `referral` · `loyalty` · `admin`.
  final String kind;

  /// `available` · `pending`.
  final String status;
  final int points;
  final String? note;

  /// Pending lots: when they become usable; null = waiting on an event
  /// (e.g. a delivery).
  final String? availableAt;
  final String? expiresAt;

  bool get isAvailable => status == 'available';

  factory PointsLot.fromJson(Map<String, dynamic> j) => PointsLot(
        kind: _str(j['kind']) ?? 'admin',
        status: _str(j['status']) ?? 'pending',
        points: _int(j['points']) ?? 0,
        note: _str(j['note']),
        availableAt: _str(j['available_at']),
        expiresAt: _str(j['expires_at']),
      );
}

class PointsHistoryEntry {
  const PointsHistoryEntry({
    required this.type,
    this.kind,
    this.points = 0,
    this.note,
    this.orderNo,
    this.at,
  });

  /// `earn` · `available` · `spend` · `refund` · `expire` · `reverse` · `adjust`.
  final String type;
  final String? kind;

  /// Signed: negative when points were used or removed.
  final int points;
  final String? note;
  final String? orderNo;
  final String? at;

  factory PointsHistoryEntry.fromJson(Map<String, dynamic> j) => PointsHistoryEntry(
        type: _str(j['type']) ?? 'adjust',
        kind: _str(j['kind']),
        points: _int(j['points']) ?? 0,
        note: _str(j['note']),
        orderNo: _str(j['order_no']),
        at: _str(j['at']),
      );
}

/// Admin-set numbers. The UI builds its rules text from these and never
/// hard-codes them.
class PointsRules {
  const PointsRules({
    this.welcomePoints,
    this.welcomeMinOrderPaise,
    this.referralPoints,
    this.redeemCapPct,
    this.loyaltyPct,
    this.expiryDays,
    this.returnWindowDays,
  });

  final int? welcomePoints;
  final int? welcomeMinOrderPaise;
  final int? referralPoints;
  final int? redeemCapPct;
  final int? loyaltyPct;
  final int? expiryDays;
  final int? returnWindowDays;

  factory PointsRules.fromJson(Map<String, dynamic> j) => PointsRules(
        welcomePoints: _int(j['welcome_points']),
        welcomeMinOrderPaise: _int(j['welcome_min_order_paise']),
        referralPoints: _int(j['referral_points']),
        redeemCapPct: _int(j['redeem_cap_pct']),
        loyaltyPct: _int(j['loyalty_pct']),
        expiryDays: _int(j['expiry_days']),
        returnWindowDays: _int(j['return_window_days']),
      );
}

class ReferralFriend {
  const ReferralFriend({required this.name, required this.status, this.joinedAt});

  final String name;

  /// `signed_up` · `qualified` · `rewarded` · `rejected`.
  final String status;
  final String? joinedAt;

  factory ReferralFriend.fromJson(Map<String, dynamic> j) => ReferralFriend(
        name: _str(j['name']) ?? 'Friend',
        status: _str(j['status']) ?? 'signed_up',
        joinedAt: _str(j['joined_at']),
      );
}

class Referral {
  const Referral({
    this.code,
    this.active = false,
    this.link,
    this.friends = const [],
    this.rewarded = 0,
  });

  final String? code;

  /// False until the customer's first store order is delivered.
  final bool active;
  final String? link;
  final List<ReferralFriend> friends;

  /// Friends whose referral points were given.
  final int rewarded;

  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
        code: _str(j['code']),
        active: j['active'] == true,
        link: _str(j['link']),
        friends: _list(j['friends'], ReferralFriend.fromJson),
        rewarded: _int(j['rewarded']) ?? 0,
      );
}

class PointsSummary {
  const PointsSummary({
    this.enabled = false,
    this.balance = const PointsBalance(),
    this.lots = const [],
    this.history = const [],
    this.rules = const PointsRules(),
    this.referral = const Referral(),
    this.shareText,
  });

  /// False → hide the Points screen and every entry point.
  final bool enabled;
  final PointsBalance balance;
  final List<PointsLot> lots;
  final List<PointsHistoryEntry> history;
  final PointsRules rules;
  final Referral referral;
  final String? shareText;

  factory PointsSummary.fromJson(Map<String, dynamic> j) => PointsSummary(
        enabled: j['enabled'] == true,
        balance: PointsBalance.fromJson(_map(j['balance'])),
        lots: _list(j['lots'], PointsLot.fromJson),
        history: _list(j['history'], PointsHistoryEntry.fromJson),
        rules: PointsRules.fromJson(_map(j['rules'])),
        referral: Referral.fromJson(_map(j['referral'])),
        shareText: _str(j['share_text']),
      );
}
