import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user_model.dart';
import 'api_service.dart';

class AdminService {
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final res = await ApiService.dio.get('/admin/stats');

      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }

      return {};
    } catch (e) {
      debugPrint('GET ADMIN STATS ERROR: $e');
      return {};
    }
  }

  Future<bool> exportCsv() async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      final path =
          '${dir.path}/pharmacy_export_${DateTime.now().millisecondsSinceEpoch}.csv';

      await ApiService.dio.download(
        '/export-csv',
        path,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      final file = File(path);

      if (!await file.exists()) {
        return false;
      }

      await OpenFilex.open(path);

      return true;
    } catch (e) {
      debugPrint('EXPORT CSV ERROR: $e');
      return false;
    }
  }

  Future<List<String>> getProvinces() async {
    try {
      final res = await ApiService.dio.get('/provinces');

      final data = res.data;

      if (data is List) {
        return data.map((e) => e.toString()).toList();
      }

      return [];
    } catch (e) {
      debugPrint('GET PROVINCES ERROR: $e');
      return [];
    }
  }

  Future<List<UserModel>> getUsers() async {
    try {
      final res = await ApiService.dio.get('/admin/users');

      final data = res.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (data is Map && data['rows'] is List) {
        return (data['rows'] as List)
            .whereType<Map>()
            .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('GET USERS ERROR: $e');
      return [];
    }
  }

  Future<bool> updateUserRole({
    required int id,
    required String role,
  }) async {
    try {
      final res = await ApiService.dio.put(
        '/admin/users/$id/role',
        data: {
          'role': role,
        },
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('UPDATE USER ROLE ERROR: $e');
      return false;
    }
  }

  Future<bool> toggleUserActive(int id) async {
    try {
      final res = await ApiService.dio.put(
        '/admin/users/$id/toggle-active',
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('TOGGLE USER ACTIVE ERROR: $e');
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      final res = await ApiService.dio.delete(
        '/admin/users/$id',
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('DELETE USER ERROR: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getAdminPharmacies({
    int page = 1,
    int perPage = 20,
    String search = '',
    String province = '',
    String district = '',
    bool hasImage = false,
    bool? isSurveyed,
  }) async {
    try {
      final res = await ApiService.dio.get(
        '/admin/pharmacies',
        queryParameters: {
          'page': page,
          'perPage': perPage,
          if (search.trim().isNotEmpty) 'search': search.trim(),
          if (province.trim().isNotEmpty) 'province': province.trim(),
          if (district.trim().isNotEmpty) 'district': district.trim(),
          'hasImage': hasImage,
          if (isSurveyed != null) 'isSurveyed': isSurveyed,
        },
      );

      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }

      return {
        'rows': [],
        'page': 1,
        'totalPages': 1,
        'total': 0,
      };
    } catch (e) {
      debugPrint('GET ADMIN PHARMACIES ERROR: $e');

      return {
        'rows': [],
        'page': 1,
        'totalPages': 1,
        'total': 0,
      };
    }
  }

  Future<bool> createAdminPharmacy({
    required String name,
    required String address,
    required String province,
    required String district,
    required String phone,
    required String status,
    required double? rating,
    required double latitude,
    required double longitude,
    required String image,
    File? imageFile,
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        'address': address,
        'province': province,
        'district': district,
        'phone': phone,
        'status': status,
        'rating': rating?.toString() ?? '',
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'image': image,
        if (imageFile != null)
          'imageFile': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          ),
      });

      final res = await ApiService.dio.post(
        '/admin/pharmacies',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('CREATE ADMIN PHARMACY ERROR: $e');
      return false;
    }
  }

  Future<bool> updateAdminPharmacy({
    required int id,
    required String name,
    required String address,
    required String province,
    required String district,
    required String phone,
    required String status,
    required double? rating,
    required double latitude,
    required double longitude,
    required String image,
    File? imageFile,
  }) async {
    try {
      final formData = FormData.fromMap({
        'name': name,
        'address': address,
        'province': province,
        'district': district,
        'phone': phone,
        'status': status,
        'rating': rating?.toString() ?? '',
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'image': image,
        if (imageFile != null)
          'imageFile': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          ),
      });

      final res = await ApiService.dio.put(
        '/admin/pharmacies/$id',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('UPDATE ADMIN PHARMACY ERROR: $e');
      return false;
    }
  }

  Future<bool> deleteAdminPharmacy(int id) async {
    try {
      final res = await ApiService.dio.delete(
        '/admin/pharmacies/$id',
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('DELETE ADMIN PHARMACY ERROR: $e');
      return false;
    }
  }
}