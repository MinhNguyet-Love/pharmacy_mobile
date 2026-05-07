class PharmacyModel {
  final int id;
  final String name;
  final String address;
  final String province;
  final String district;
  final String phone;
  final String status;
  final double? rating;
  final String imageUrl;
  final List<String> productGroups;
  final bool isSurveyed;
  final String? surveyedAt;
  final double lat;
  final double lng;

  PharmacyModel({
    required this.id,
    required this.name,
    required this.address,
    required this.province,
    required this.district,
    required this.phone,
    required this.status,
    required this.rating,
    required this.imageUrl,
    required this.productGroups,
    required this.isSurveyed,
    required this.surveyedAt,
    required this.lat,
    required this.lng,
  });

  factory PharmacyModel.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'] ?? {};
    final geometry = feature['geometry'] ?? {};
    final coordinates = geometry['coordinates'] ?? [0.0, 0.0];

    return PharmacyModel(
      id: _toInt(properties['id']),
      name: properties['name']?.toString() ?? '',
      address: properties['address']?.toString() ?? '',
      province: properties['province']?.toString() ?? '',
      district: properties['district']?.toString() ?? '',
      phone: properties['phone']?.toString() ?? '',
      status: properties['status']?.toString() ?? '',
      rating: _toDoubleNullable(properties['rating']),
      imageUrl: properties['image_url']?.toString() ?? '',
      productGroups: _toStringList(properties['product_groups']),
      isSurveyed: properties['is_surveyed'] == true,
      surveyedAt: properties['surveyed_at']?.toString(),
      lat: coordinates.length > 1 ? _toDouble(coordinates[1]) : 0.0,
      lng: coordinates.isNotEmpty ? _toDouble(coordinates[0]) : 0.0,
    );
  }

  factory PharmacyModel.fromJson(Map<String, dynamic> json) {
    return PharmacyModel(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      rating: _toDoubleNullable(json['rating']),
      imageUrl: json['image_url']?.toString() ?? '',
      productGroups: _toStringList(json['product_groups']),
      isSurveyed: json['is_surveyed'] == true,
      surveyedAt: json['surveyed_at']?.toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'status': status,
      'rating': rating,
      'image_url': imageUrl,
      'product_groups': productGroups,
    };
  }

  PharmacyModel copyWith({
    int? id,
    String? name,
    String? address,
    String? province,
    String? district,
    String? phone,
    String? status,
    double? rating,
    String? imageUrl,
    List<String>? productGroups,
    bool? isSurveyed,
    String? surveyedAt,
    double? lat,
    double? lng,
  }) {
    return PharmacyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      province: province ?? this.province,
      district: district ?? this.district,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
      productGroups: productGroups ?? this.productGroups,
      isSurveyed: isSurveyed ?? this.isSurveyed,
      surveyedAt: surveyedAt ?? this.surveyedAt,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static double? _toDoubleNullable(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    return [];
  }
}