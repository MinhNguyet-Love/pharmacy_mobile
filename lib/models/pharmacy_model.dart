class PharmacyModel {
  final int id;
  final String name;
  final String address;
  final String province;
  final String district;

  final String ward;
  final String streetAddress;
  final String businessType;
  final String surveyNote;

  final String phone;
  final String status;
  final double? rating;
  final String imageUrl;
  final List<String> productGroups;
  final String ownerName;
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
    required this.ward,
    required this.streetAddress,
    required this.businessType,
    required this.surveyNote,
    required this.phone,
    required this.status,
    required this.rating,
    required this.imageUrl,
    required this.productGroups,
    required this.ownerName,
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
      ward: properties['ward']?.toString() ?? '',
      streetAddress: properties['street_address']?.toString() ?? '',
      businessType: properties['business_type']?.toString() ?? '',
      surveyNote: properties['survey_note']?.toString() ?? '',
      phone: properties['phone']?.toString() ?? '',
      status: properties['status']?.toString() ?? '',
      rating: _toDoubleNullable(properties['rating']),
      imageUrl: properties['image_url']?.toString() ?? '',
      productGroups: _toStringList(properties['product_groups']),
      ownerName: properties['owner_name']?.toString() ?? '',
      isSurveyed: _toBool(properties['is_surveyed']),
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
      ward: json['ward']?.toString() ?? '',
      streetAddress: json['street_address']?.toString() ?? '',
      businessType: json['business_type']?.toString() ?? '',
      surveyNote: json['survey_note']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      rating: _toDoubleNullable(json['rating']),
      imageUrl: json['image_url']?.toString() ?? '',
      productGroups: _toStringList(json['product_groups']),
      ownerName: json['owner_name']?.toString() ?? '',
      isSurveyed: _toBool(json['is_surveyed']),
      surveyedAt: json['surveyed_at']?.toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'address': address,
      'province': province,
      'district': district,
      'ward': ward,
      'street_address': streetAddress,
      'business_type': businessType,
      'survey_note': surveyNote,
      'phone': phone,
      'status': status,
      'rating': rating,
      'image_url': imageUrl,
      'product_groups': productGroups,
      'owner_name': ownerName,
    };
  }

  PharmacyModel copyWith({
    int? id,
    String? name,
    String? address,
    String? province,
    String? district,
    String? ward,
    String? streetAddress,
    String? businessType,
    String? surveyNote,
    String? phone,
    String? status,
    double? rating,
    String? imageUrl,
    List<String>? productGroups,
    String? ownerName,
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
      ward: ward ?? this.ward,
      streetAddress: streetAddress ?? this.streetAddress,
      businessType: businessType ?? this.businessType,
      surveyNote: surveyNote ?? this.surveyNote,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
      productGroups: productGroups ?? this.productGroups,
      ownerName: ownerName ?? this.ownerName,
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

  static bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;

    final text = value?.toString().toLowerCase().trim();

    return text == 'true' || text == '1' || text == 'yes';
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    return [];
  }
}