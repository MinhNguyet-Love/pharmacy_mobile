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
    int limit = 50000,
  }) async {
    try {
      final response = await ApiService.dio.get(
        '/pharmacies.geojson',
        queryParameters: {
          if (province != null && province.isNotEmpty) 'province': province,
          if (ratingMin != null) 'rating_min': ratingMin,
          'limit': limit,
        },
      );

      final data = response.data;
      final features = (data['features'] as List<dynamic>? ?? []);

      return features
          .map((e) => PharmacyModel.fromGeoJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      print('GET PHARMACIES ERROR: $e');
      return [];
    }
  }
}