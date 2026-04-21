import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final Dio _dio = ApiService.dio;

  Future<Map<String, dynamic>> register(
      String fullname,
      String email,
      String password,
      ) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'fullname': fullname,
          'email': email,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;

      return {
        'success': data['success'] == true,
        'message': data['message']?.toString() ?? 'Đăng ký thành công',
        'user': data['user'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['message']?.toString() ??
            'Không thể đăng ký. Vui lòng thử lại.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Đã xảy ra lỗi không xác định.',
      };
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';
      final userJson = Map<String, dynamic>.from(data['user'] ?? {});
      final user = UserModel.fromJson(userJson);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setInt('user_id', user.id);
      await prefs.setString('fullname', user.fullname);
      await prefs.setString('email', user.email);
      await prefs.setString('role', user.role);

      return {
        'success': data['success'] == true,
        'message': data['message']?.toString() ?? 'Đăng nhập thành công',
        'token': token,
        'user': user,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['message']?.toString() ??
            'Không thể đăng nhập. Vui lòng thử lại.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Đã xảy ra lỗi không xác định.',
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('fullname');
    await prefs.remove('email');
    await prefs.remove('role');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    final fullname = prefs.getString('fullname');
    final email = prefs.getString('email');
    final role = prefs.getString('role');

    if (id == null || fullname == null || email == null || role == null) {
      return null;
    }

    return UserModel(
      id: id,
      fullname: fullname,
      email: email,
      role: role,
    );
  }
}