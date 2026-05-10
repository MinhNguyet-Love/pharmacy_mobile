import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../map/map_screen.dart';
import 'pharmacies/admin_pharmacies_screen.dart';
import 'survey/admin_surveyed_screen.dart';
import 'users/admin_users_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final UserModel user;

  const AdminHomeScreen({
    super.key,
    required this.user,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final AdminService _adminService = AdminService();

  bool _loadingStats = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);

    final stats = await _adminService.getAdminStats();

    if (!mounted) return;

    setState(() {
      _stats = stats;
      _loadingStats = false;
    });
  }

  int _num(String key) {
    final value = _stats[key];

    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _AdminHeader(user: user),

            const SizedBox(height: 24),

            _AdminMenuCard(
              icon: Icons.map_outlined,
              title: 'Bản đồ nhà thuốc',
              subtitle: 'Xem map, heatmap, khảo sát nhà thuốc',
              color: Colors.pink,
              onTap: () => _go(
                context,
                const MapScreen(role: 'admin'),
              ),
            ),

            _AdminMenuCard(
              icon: Icons.people_alt_outlined,
              title: 'Quản lý User',
              subtitle: 'Xem user, tìm kiếm, đổi role, xoá tài khoản',
              color: Colors.blue,
              onTap: () => _go(
                context,
                const AdminUsersScreen(),
              ),
            ),

            _AdminMenuCard(
              icon: Icons.local_pharmacy_outlined,
              title: 'Quản lý Nhà thuốc',
              subtitle: 'Tìm kiếm, lọc tỉnh, xem chi tiết, sửa, xoá',
              color: Colors.green,
              onTap: () => _go(
                context,
                const AdminPharmaciesScreen(),
              ),
            ),

            _AdminMenuCard(
              icon: Icons.fact_check_outlined,
              title: 'Quản lý Khảo sát',
              subtitle: 'Xem nhà thuốc đã khảo sát, thời gian và ảnh',
              color: Colors.orange,
              onTap: () => _go(
                context,
                const AdminSurveyedScreen(),
              ),
            ),

            const SizedBox(height: 28),

            _StatsGrid(
              loading: _loadingStats,
              totalPharmacies: _num('total_pharmacies'),
              surveyedPharmacies: _num('surveyed_pharmacies'),
              unsurveyedPharmacies: _num('unsurveyed_pharmacies'),
              totalUsers: _num('total_users'),
              companyUsers: _num('company_users'),
              adminUsers: _num('admin_users'),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  final UserModel user;

  const _AdminHeader({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE91E63),
            Color(0xFFFF7AAE),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.admin_panel_settings,
              color: Colors.pink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullname.isEmpty
                      ? 'Admin'
                      : user.fullname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final bool loading;
  final int totalPharmacies;
  final int surveyedPharmacies;
  final int unsurveyedPharmacies;
  final int totalUsers;
  final int companyUsers;
  final int adminUsers;

  const _StatsGrid({
    required this.loading,
    required this.totalPharmacies,
    required this.surveyedPharmacies,
    required this.unsurveyedPharmacies,
    required this.totalUsers,
    required this.companyUsers,
    required this.adminUsers,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.pink,
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      childAspectRatio: 1.45,
      children: [
        _StatCard(
          'Tổng nhà thuốc',
          totalPharmacies,
          Icons.local_pharmacy,
          Colors.pink,
        ),
        _StatCard(
          'Đã khảo sát',
          surveyedPharmacies,
          Icons.verified,
          Colors.green,
        ),
        _StatCard(
          'Chưa khảo sát',
          unsurveyedPharmacies,
          Icons.pending_actions,
          Colors.orange,
        ),
        _StatCard(
          'Tổng user',
          totalUsers,
          Icons.people,
          Colors.blue,
        ),
        _StatCard(
          'Company',
          companyUsers,
          Icons.business,
          Colors.indigo,
        ),
        _StatCard(
          'Admin',
          adminUsers,
          Icons.admin_panel_settings,
          Colors.red,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard(
      this.title,
      this.value,
      this.icon,
      this.color,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8.5,
              color: Colors.black54,
              height: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.25,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}