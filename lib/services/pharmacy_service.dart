import 'dart:io';

import 'package:dio/dio.dart';

import '../models/pharmacy_model.dart';
import 'api_service.dart';

class PharmacyService {
  Future<List<String>> getProvinces() async {
    try {
      final response = await ApiService.dio.get('/provinces');
      final data = response.data;

      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }

      return [];
    } catch (e) {
      print('GET PROVINCES ERROR: $e');
      return [];
    }
  }

  Future<int> getPharmacyCount() async {
    try {
      final response = await ApiService.dio.get('/pharmacies/count');
      final data = response.data;

      if (data is Map && data['total'] != null) {
        return int.tryParse(data['total'].toString()) ?? 0;
      }

      return 0;
    } catch (e) {
      print('GET PHARMACY COUNT ERROR: $e');
      return 0;
    }
  }

  Future<List<PharmacyModel>> getPharmaciesGeoJson({
    String? bbox,
    String? mode,
    String? search,
    String? province,
    String? district,
    double? ratingMin,
    int? limit,
  }) async {
    try {
      final query = <String, dynamic>{};

      if (bbox != null && bbox.trim().isNotEmpty) query['bbox'] = bbox;
      if (mode != null && mode.trim().isNotEmpty) query['mode'] = mode;
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (province != null && province.trim().isNotEmpty) {
        query['province'] = province.trim();
      }
      if (district != null && district.trim().isNotEmpty) {
        query['district'] = district.trim();
      }
      if (ratingMin != null) query['rating_min'] = ratingMin;
      if (limit != null && limit > 0) query['limit'] = limit;

      final response = await ApiService.dio.get(
        '/pharmacies.geojson',
        queryParameters: query,
      );

      return _parseGeoJsonResponse(response.data);
    } on DioException catch (e) {
      print('GET PHARMACIES GEOJSON DIO ERROR: ${e.message}');
      print('STATUS: ${e.response?.statusCode}');
      print('DATA: ${e.response?.data}');
      return [];
    } catch (e) {
      print('GET PHARMACIES GEOJSON ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getHeatmap({
    String? province,
    double? ratingMin,
    double? minLng,
    double? minLat,
    double? maxLng,
    double? maxLat,
  }) async {
    try {
      final query = <String, dynamic>{};

      if (province != null && province.trim().isNotEmpty) {
        query['province'] = province.trim();
      }

      if (ratingMin != null) query['rating_min'] = ratingMin;

      if (minLng != null &&
          minLat != null &&
          maxLng != null &&
          maxLat != null) {
        query['bbox'] = '$minLng,$minLat,$maxLng,$maxLat';
      }

      final response = await ApiService.dio.get(
        '/heatmap',
        queryParameters: query,
      );

      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('GET HEATMAP ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProvinceStats() async {
    try {
      final response = await ApiService.dio.get('/stats/province');
      final data = response.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('GET PROVINCE STATS ERROR: $e');
      return [];
    }
  }

  Future<String?> uploadPharmacyImage(File imageFile) async {
    try {
      final fileName = imageFile.path.split('/').last;

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await ApiService.dio.post(
        '/upload-image',
        data: formData,
      );

      final data = response.data;

      if (data is Map && data['image_url'] != null) {
        return data['image_url'].toString();
      }

      return null;
    } catch (e) {
      print('UPLOAD IMAGE ERROR: $e');
      return null;
    }
  }

  Future<PharmacyModel?> updatePharmacy({
    required int id,
    String? name,
    String? address,
    String? province,
    String? district,
    String? phone,
    String? status,
    double? rating,
    String? imageUrl,
    List<String>? productGroups,
    String? ownerName,
  }) async {
    try {
      print('UPDATE PHARMACY URL: /pharmacies/$id');

      final response = await ApiService.dio.put(
        '/pharmacies/$id',
        data: {
          'name': name,
          'address': address,
          'province': province,
          'district': district,
          'phone': phone,
          'status': status,
          'rating': rating,
          'image_url': imageUrl,
          'product_groups': productGroups,
          'owner_name': ownerName,
        },
      );

      final data = response.data;

      if (data is Map && data['pharmacy'] is Map) {
        return PharmacyModel.fromJson(
          Map<String, dynamic>.from(data['pharmacy']),
        );
      }

      if (data is Map) {
        return PharmacyModel.fromJson(
          Map<String, dynamic>.from(data),
        );
      }

      return null;
    } on DioException catch (e) {
      print('UPDATE PHARMACY DIO ERROR STATUS: ${e.response?.statusCode}');
      print('UPDATE PHARMACY DIO ERROR DATA: ${e.response?.data}');
      return null;
    } catch (e) {
      print('UPDATE PHARMACY ERROR: $e');
      return null;
    }
  }

  List<PharmacyModel> _parseGeoJsonResponse(dynamic data) {
    if (data is! Map) return [];

    final features = data['features'];

    if (features is! List) return [];

    return features
        .whereType<Map>()
        .map((feature) {
      return PharmacyModel.fromGeoJson(
        Map<String, dynamic>.from(feature),
      );
    })
        .where((p) => p.id > 0 && p.lat != 0 && p.lng != 0)
        .toList();
  }
}