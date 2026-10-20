class Home {
  const Home({
    required this.id,
    required this.name,
    this.address = '104 Lumivo Way',
    this.role = 'Owner',
    this.isCurrent = false,
    this.tariffRate = 0.16, // $0.16 per kWh
    this.currency = 'USD',
    this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final String role;
  final bool isCurrent;
  final double tariffRate;
  final String currency;
  final DateTime? createdAt;

  Home copyWith({
    String? id,
    String? name,
    String? address,
    String? role,
    bool? isCurrent,
    double? tariffRate,
    String? currency,
    DateTime? createdAt,
  }) =>
      Home(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        role: role ?? this.role,
        isCurrent: isCurrent ?? this.isCurrent,
        tariffRate: tariffRate ?? this.tariffRate,
        currency: currency ?? this.currency,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'role': role,
        'isCurrent': isCurrent,
        'tariffRate': tariffRate,
        'currency': currency,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Home.fromJson(Map<String, dynamic> json) => Home(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '104 Lumivo Way',
        role: json['role'] as String? ?? 'Owner',
        isCurrent: json['isCurrent'] as bool? ?? false,
        tariffRate: (json['tariffRate'] as num?)?.toDouble() ?? 0.16,
        currency: json['currency'] as String? ?? 'USD',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}
