import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiService.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      print('LOGIN STATUS CODE: ${response.statusCode}');
      print('LOGIN RESPONSE DATA: ${response.data}');

      final data = response.data;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token'] ?? '');
      await prefs.setString('role', data['user']?['role'] ?? '');
      await prefs.setString('email', data['user']?['email'] ?? email);
      await prefs.setString('fullname', data['user']?['fullname'] ?? '');

      return {
        'success': true,
        'data': data,
      };
    } on DioException catch (e) {
      print('LOGIN DIO ERROR TYPE: ${e.type}');
      print('LOGIN DIO ERROR MESSAGE: ${e.message}');
      print('LOGIN DIO ERROR RESPONSE: ${e.response?.data}');
      print('LOGIN DIO ERROR STATUS: ${e.response?.statusCode}');

      String message = 'Đăng nhập thất bại';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        message = 'Máy chủ phản hồi quá chậm, vui lòng thử lại sau ít giây';
      } else {
        message = e.response?.data?['message']?.toString() ??
            e.message ??
            'Đăng nhập thất bại';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('LOGIN OTHER ERROR: $e');
      return {
        'success': false,
        'message': 'Có lỗi xảy ra: $e',
      };
    }
  }

  Future<Map<String, dynamic>> register(
      String fullname,
      String email,
      String password,
      ) async {
    try {
      final response = await ApiService.dio.post(
        '/auth/register',
        data: {
          'fullname': fullname,
          'email': email,
          'password': password,
        },
      );

      print('REGISTER STATUS CODE: ${response.statusCode}');
      print('REGISTER RESPONSE DATA: ${response.data}');

      return {
        'success': true,
        'data': response.data,
      };
    } on DioException catch (e) {
      print('REGISTER DIO ERROR TYPE: ${e.type}');
      print('REGISTER DIO ERROR MESSAGE: ${e.message}');
      print('REGISTER DIO ERROR RESPONSE: ${e.response?.data}');
      print('REGISTER DIO ERROR STATUS: ${e.response?.statusCode}');

      String message = 'Đăng ký thất bại';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        message = 'Máy chủ phản hồi quá chậm, vui lòng thử lại sau ít giây';
      } else {
        message = e.response?.data?['message']?.toString() ??
            e.message ??
            'Đăng ký thất bại';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      print('REGISTER OTHER ERROR: $e');
      return {
        'success': false,
        'message': 'Có lỗi xảy ra: $e',
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}