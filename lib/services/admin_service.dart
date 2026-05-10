// import 'dart:io';
//
// import 'package:dio/dio.dart';
//
// import '../models/user_model.dart';
// import '../models/pharmacy_model.dart';
// import 'api_service.dart';
//
// class AdminService {
//   Future<List<UserModel>> getUsers() async {
//     try {
//       final res = await ApiService.dio.get('/admin/users');
//
//       final data = res.data;
//
//       if (data is List) {
//         return data.map((e) => UserModel.fromJson(e)).toList();
//       }
//
//       if (data is Map && data['rows'] is List) {
//         return (data['rows'] as List)
//             .map((e) => UserModel.fromJson(e))
//             .toList();
//       }
//
//       return [];
//     } catch (e) {
//       print('GET USERS ERROR: $e');
//       return [];
//     }
//   }
//
//   Future<bool> updateUserRole({
//     required int id,
//     required String role,
//   }) async {
//     try {
//       await ApiService.dio.put(
//         '/admin/users/$id/role',
//         data: {'role': role},
//       );
//       return true;
//     } catch (e) {
//       print('UPDATE USER ROLE ERROR: $e');
//       return false;
//     }
//   }
//
//   Future<bool> deleteUser(int id) async {
//     try {
//       await ApiService.dio.delete('/admin/users/$id');
//       return true;
//     } catch (e) {
//       print('DELETE USER ERROR: $e');
//       return false;
//     }
//   }
//
//   Future<Map<String, dynamic>> getAdminPharmacies({
//     int page = 1,
//     int perPage = 20,
//     String search = '',
//     String province = '',
//     String district = '',
//     bool hasImage = false,
//   }) async {
//     try {
//       final res = await ApiService.dio.get(
//         '/admin/pharmacies',
//         queryParameters: {
//           'page': page,
//           'perPage': perPage,
//           if (search.trim().isNotEmpty) 'search': search.trim(),
//           if (province.trim().isNotEmpty) 'province': province.trim(),
//           if (district.trim().isNotEmpty) 'district': district.trim(),
//           'hasImage': hasImage,
//         },
//       );
//
//       final data = res.data;
//
//       if (data is Map<String, dynamic>) {
//         return data;
//       }
//
//       return {
//         'rows': [],
//         'total': 0,
//         'page': 1,
//         'totalPages': 1,
//       };
//     } catch (e) {
//       print('GET ADMIN PHARMACIES ERROR: $e');
//       return {
//         'rows': [],
//         'total': 0,
//         'page': 1,
//         'totalPages': 1,
//       };
//     }
//   }
//
//   Future<bool> updateAdminPharmacy({
//     required int id,
//     required String name,
//     required String address,
//     required String province,
//     required String district,
//     required String phone,
//     required String status,
//     required double? rating,
//     required double latitude,
//     required double longitude,
//     required String image,
//     File? imageFile,
//   }) async {
//     try {
//       final formData = FormData.fromMap({
//         'name': name,
//         'address': address,
//         'province': province,
//         'district': district,
//         'phone': phone,
//         'status': status,
//         'rating': rating?.toString() ?? '',
//         'latitude': latitude.toString(),
//         'longitude': longitude.toString(),
//         'image': image,
//         if (imageFile != null)
//           'imageFile': await MultipartFile.fromFile(
//             imageFile.path,
//             filename: imageFile.path.split('/').last,
//           ),
//       });
//
//       await ApiService.dio.put(
//         '/admin/pharmacies/$id',
//         data: formData,
//         options: Options(contentType: 'multipart/form-data'),
//       );
//
//       return true;
//     } catch (e) {
//       print('UPDATE ADMIN PHARMACY ERROR: $e');
//       return false;
//     }
//   }
//
//   Future<bool> deleteAdminPharmacy(int id) async {
//     try {
//       await ApiService.dio.delete('/admin/pharmacies/$id');
//       return true;
//     } catch (e) {
//       print('DELETE ADMIN PHARMACY ERROR: $e');
//       return false;
//     }
//   }
// }
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/user_model.dart';
import 'api_service.dart';

class AdminService {
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final res = await ApiService.dio.get('/admin/stats');
      if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
      return {};
    } catch (e) {
      print('GET ADMIN STATS ERROR: $e');
      return {};
    }
  }

  Future<List<UserModel>> getUsers() async {
    try {
      final res = await ApiService.dio.get('/admin/users');
      final data = res.data;
      if (data is List) return data.map((e) => UserModel.fromJson(e)).toList();
      if (data is Map && data['rows'] is List) {
        return (data['rows'] as List).map((e) => UserModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('GET USERS ERROR: $e');
      return [];
    }
  }

  Future<bool> updateUserRole({required int id, required String role}) async {
    try {
      await ApiService.dio.put('/admin/users/$id/role', data: {'role': role});
      return true;
    } catch (e) {
      print('UPDATE USER ROLE ERROR: $e');
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await ApiService.dio.delete('/admin/users/$id');
      return true;
    } catch (e) {
      print('DELETE USER ERROR: $e');
      return false;
    }
  }

  Future<List<String>> getProvinces() async {
    try {
      final res = await ApiService.dio.get('/provinces');
      final data = res.data;
      if (data is List) return data.map((e) => e.toString()).toList();
      return [];
    } catch (e) {
      print('GET PROVINCES ERROR: $e');
      return [];
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
      if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
      return {'rows': [], 'total': 0, 'page': 1, 'totalPages': 1};
    } catch (e) {
      print('GET ADMIN PHARMACIES ERROR: $e');
      return {'rows': [], 'total': 0, 'page': 1, 'totalPages': 1};
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
          'imageFile': await MultipartFile.fromFile(imageFile.path, filename: imageFile.path.split('/').last),
      });

      await ApiService.dio.put(
        '/admin/pharmacies/$id',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return true;
    } catch (e) {
      print('UPDATE ADMIN PHARMACY ERROR: $e');
      return false;
    }
  }

  Future<bool> deleteAdminPharmacy(int id) async {
    try {
      await ApiService.dio.delete('/admin/pharmacies/$id');
      return true;
    } catch (e) {
      print('DELETE ADMIN PHARMACY ERROR: $e');
      return false;
    }
  }
}
