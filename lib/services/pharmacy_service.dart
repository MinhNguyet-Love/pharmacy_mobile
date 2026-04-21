import '../models/pharmacy_model.dart';
import 'api_service.dart';

class PharmacyService {
  Future<List<String>> getProvinces() async {
    try {
      final response = await ApiService.dio.get('/provinces');
      final data = response.data as List<dynamic>;
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      print('GET PROVINCES ERROR: $e');
      return [];
    }
  }

  Future<List<PharmacyModel>> getPharmacies({
    String? province,
    double? ratingMin,
    int limit = 5000,
  }) async {
    try {
      final response = await ApiService.dio.get(
        '/pharmacies',
        queryParameters: {
          if (province != null && province.isNotEmpty) 'province': province,
          if (ratingMin != null) 'rating_min': ratingMin,
          'limit': limit,
        },
      );

      final data = response.data as List<dynamic>;

      return data.map((e) {
        final item = Map<String, dynamic>.from(e);
        return PharmacyModel(
          name: item['name']?.toString() ?? '',
          address: item['address']?.toString() ?? '',
          province: item['province']?.toString() ?? '',
          district: item['district']?.toString() ?? '',
          phone: item['phone']?.toString() ?? '',
          status: item['status']?.toString() ?? '',
          rating: item['rating'] == null
              ? null
              : double.tryParse(item['rating'].toString()),
          image: item['image']?.toString() ?? '',
          lng: double.tryParse(
            item['lon']?.toString() ?? item['lng']?.toString() ?? '0',
          ) ??
              0,
          lat: double.tryParse(item['lat']?.toString() ?? '0') ?? 0,
        );
      }).toList();
    } catch (e) {
      print('GET PHARMACIES ERROR: $e');
      return [];
    }
  }

  Future<List<PharmacyModel>> getPharmaciesGeoJson({
    required String bbox,
    String? province,
    double? ratingMin,
  }) async {
    try {
      final response = await ApiService.dio.get(
        '/pharmacies.geojson',
        queryParameters: {
          'bbox': bbox,
          if (province != null && province.isNotEmpty) 'province': province,
          if (ratingMin != null) 'rating_min': ratingMin,
        },
      );

      final data = response.data;
      final features = (data['features'] as List<dynamic>? ?? []);

      return features
          .map((e) => PharmacyModel.fromGeoJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('GET PHARMACIES GEOJSON ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getHeatmap({
    String? province,
    double? ratingMin,
  }) async {
    try {
      final response = await ApiService.dio.get(
        '/heat',
        queryParameters: {
          if (province != null && province.isNotEmpty) 'province': province,
          if (ratingMin != null) 'rating_min': ratingMin,
        },
      );

      final data = response.data as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('GET HEATMAP ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProvinceStats() async {
    try {
      final response = await ApiService.dio.get('/stats/province');
      final data = response.data as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('GET PROVINCE STATS ERROR: $e');
      return [];
    }
  }
}