class PharmacyModel {
  final int id;
  final String name;
  final String address;
  final String province;
  final String district;
  final String phone;
  final String status;
  final double? rating;
  final String image;
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
    required this.image,
    required this.lat,
    required this.lng,
  });

  factory PharmacyModel.fromGeoJson(Map<String, dynamic> feature) {
    final properties = feature['properties'] ?? {};
    final geometry = feature['geometry'] ?? {};
    final coordinates = geometry['coordinates'] ?? [0.0, 0.0];

    return PharmacyModel(
      id: int.tryParse(properties['id']?.toString() ?? '0') ?? 0,
      name: properties['name']?.toString() ?? '',
      address: properties['address']?.toString() ?? '',
      province: properties['province']?.toString() ?? '',
      district: properties['district']?.toString() ?? '',
      phone: properties['phone']?.toString() ?? '',
      status: properties['status']?.toString() ?? '',
      rating: properties['rating'] == null
          ? null
          : double.tryParse(properties['rating'].toString()),
      image: properties['image']?.toString() ??
          properties['image_url']?.toString() ??
          '',
      lng: (coordinates[0] as num?)?.toDouble() ?? 0,
      lat: (coordinates[1] as num?)?.toDouble() ?? 0,
    );
  }
}