class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    this.doctorName,
    this.clinicName,
    this.specLabel,
    this.spec,
    this.rating,
    this.reviews,
    this.area,
    this.city,
    this.state,
    this.fee,
    this.currency,
    this.phone,
    this.gmapsUrl,
    this.address,
    this.photoUrl,
    this.verified = false,
    this.isClaimed = false,
    this.canRequestAppointment = true,
    this.initials,
    this.nextLabel,
    this.openingHours = const [],
  });

  final int id;
  final String name;
  final String? doctorName;
  final String? clinicName;
  final String? specLabel;
  final String? spec;
  final double? rating;
  final int? reviews;
  final String? area;
  final String? city;
  final String? state;
  final num? fee;
  final String? currency;
  final String? phone;
  final String? gmapsUrl;
  final String? address;
  final String? photoUrl;
  final bool verified;
  final bool isClaimed;
  final bool canRequestAppointment;
  final String? initials;
  final String? nextLabel;
  final List<String> openingHours;

  String get displayName =>
      (doctorName != null && doctorName!.trim().isNotEmpty) ? doctorName! : name;

  String get locationLine {
    final parts = [area, city].where((e) => e != null && e!.trim().isNotEmpty);
    return parts.join(', ');
  }

  String get feeLabel {
    if (fee == null || fee == 0) return 'Fee on request';
    return '${currency ?? '₹'}${fee!.toStringAsFixed(0)}';
  }

  factory Doctor.fromJson(Map<String, dynamic> json) {
    final hours = json['opening_hours'];
    return Doctor(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      doctorName: json['doctorName']?.toString(),
      clinicName: json['clinicName']?.toString() ?? json['hospital']?.toString(),
      specLabel: json['specLabel']?.toString(),
      spec: json['spec']?.toString(),
      rating: json['rating'] == null ? null : (json['rating'] as num).toDouble(),
      reviews: json['reviews'] == null ? null : (json['reviews'] as num).toInt(),
      area: json['area']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      fee: json['fee'] as num?,
      currency: json['currency']?.toString(),
      phone: json['phone']?.toString(),
      gmapsUrl: json['gmaps_url']?.toString(),
      address: json['address']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      verified: json['verified'] == true,
      isClaimed: json['is_claimed'] == true,
      canRequestAppointment: json['can_request_appointment'] != false,
      initials: json['initials']?.toString() ??
          '${json['firstInitial'] ?? ''}${json['lastInitial'] ?? ''}',
      nextLabel: (json['next'] is Map)
          ? (json['next']['label']?.toString())
          : null,
      openingHours: hours is List
          ? hours.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class DoctorSearchResult {
  const DoctorSearchResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.hasMore,
    required this.total,
  });

  final List<Doctor> items;
  final int page;
  final int perPage;
  final bool hasMore;
  final int total;

  factory DoctorSearchResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Doctor.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Doctor>[];
    return DoctorSearchResult(
      items: items,
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 20,
      hasMore: json['has_more'] == true,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }
}
