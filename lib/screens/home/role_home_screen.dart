import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../admin/admin_home_screen.dart';
import '../auth/login_screen.dart';
import '../company/company_home_screen.dart';
import '../user/user_home_screen.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key});

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  final AuthService _authService = AuthService();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAndRedirect();
  }

  Future<void> _loadAndRedirect() async {
    final user = await _authService.getCurrentUser();

    if (!mounted) return;

    if (user == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
      return;
    }

    Widget target;

    switch (user.role.toLowerCase()) {
      case 'admin':
        target = AdminHomeScreen(user: user);
        break;
      case 'company':
        target = CompanyHomeScreen(user: user);
        break;
      default:
        target = UserHomeScreen(user: user);
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Colors.pink)
            : const SizedBox.shrink(),
      ),
    );
  }
}