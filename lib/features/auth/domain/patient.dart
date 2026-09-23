class Patient {
  const Patient({
    required this.id,
    required this.name,
    this.firstName,
    this.phone,
    this.email,
  });

  final int id;
  final String name;
  final String? firstName;
  final String? phone;
  final String? email;

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      firstName: json['first_name']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }
}
