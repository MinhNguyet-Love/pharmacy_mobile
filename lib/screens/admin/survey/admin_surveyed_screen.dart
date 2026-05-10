import 'package:flutter/material.dart';

import '../../../services/admin_service.dart';

class AdminSurveyedScreen extends StatefulWidget {
  const AdminSurveyedScreen({super.key});

  @override
  State<AdminSurveyedScreen> createState() => _AdminSurveyedScreenState();
}

class _AdminSurveyedScreenState extends State<AdminSurveyedScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  String _statusFilter = 'surveyed';

  @override
  void initState() {
    super.initState();
    _loadData(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool? get _isSurveyedQuery {
    if (_statusFilter == 'surveyed') return true;
    if (_statusFilter == 'unsurveyed') return false;
    return null;
  }

  Future<void> _loadData({int? page}) async {
    setState(() => _loading = true);

    final data = await _adminService.getAdminPharmacies(
      page: page ?? _page,
      perPage: 20,
      search: _searchController.text.trim(),
      isSurveyed: _isSurveyedQuery,
    );

    if (!mounted) return;

    setState(() {
      _rows = ((data['rows'] ?? []) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _page = data['page'] ?? 1;
      _totalPages = data['totalPages'] ?? 1;
      _total = data['total'] ?? 0;
      _loading = false;
    });
  }

  bool _boolValue(dynamic value) {
    if (value == true) return true;
    if (value?.toString().toLowerCase() == 'true') return true;
    if (value?.toString() == '1') return true;
    return false;
  }

  String _imageUrl(String image) {
    final v = image.trim();

    if (v.isEmpty) return '';

    if (v.startsWith('http')) {
      return v;
    }

    if (v.startsWith('/uploads')) {
      return 'https://pharmacy-backend-y6zm.onrender.com$v';
    }

    if (v.startsWith('uploads')) {
      return 'https://pharmacy-backend-y6zm.onrender.com/$v';
    }

    return v;
  }

  void _setStatusFilter(String value) {
    setState(() {
      _statusFilter = value;
    });

    _loadData(page: 1);
  }

  void _showImage(String image) {
    final url = _imageUrl(image);

    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return Container(
                          height: 260,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            color: Colors.pink,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 260,
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.red,
                                size: 52,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Không tải được ảnh khảo sát',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetail(Map<String, dynamic> p) {
    final img = p['image']?.toString() ?? '';
    final surveyed = _boolValue(p['is_surveyed']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (img.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showImage(img),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          _imageUrl(img),
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;

                            return Container(
                              height: 190,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE4EE),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const CircularProgressIndicator(
                                color: Colors.pink,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return Container(
                              height: 160,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE4EE),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text('Không tải được ảnh'),
                            );
                          },
                        ),
                      ),
                    ),

                  if (img.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => _showImage(img),
                        icon: const Icon(Icons.zoom_in),
                        label: const Text('Xem ảnh'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  Text(
                    p['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _SurveyBadge(isSurveyed: surveyed),

                  const SizedBox(height: 14),

                  _detail('Địa chỉ', p['address']),
                  _detail('Tỉnh / Thành', p['province']),
                  _detail('Quận / Huyện', p['district']),
                  _detail('Số điện thoại', p['phone']),
                  _detail('Rating', p['rating']),
                  _detail('Thời gian khảo sát', p['surveyed_at']),
                  _detail(
                    'Người khảo sát',
                    p['surveyed_by']?.toString().isNotEmpty == true
                        ? p['surveyed_by']
                        : 'Chưa có dữ liệu',
                  ),
                  _detail(
                    'Ảnh khảo sát',
                    img.isEmpty ? 'Không có ảnh' : img,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detail(String title, dynamic value) {
    final text = value?.toString() ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$title: ${text.isEmpty ? 'Không có' : text}',
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _chip('all', 'Tất cả', Icons.list_alt),
          const SizedBox(width: 8),
          _chip('surveyed', 'Đã khảo sát', Icons.verified),
          const SizedBox(width: 8),
          _chip('unsurveyed', 'Chưa khảo sát', Icons.pending_actions),
        ],
      ),
    );
  }

  Widget _chip(String value, String label, IconData icon) {
    final selected = _statusFilter == value;

    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: selected ? Colors.white : Colors.pink,
          ),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
      selectedColor: Colors.pink,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) => _setStatusFilter(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _statusFilter == 'surveyed'
        ? 'Đã khảo sát'
        : _statusFilter == 'unsurveyed'
        ? 'Chưa khảo sát'
        : 'Tất cả nhà thuốc';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Khảo sát'),
        actions: [
          IconButton(
            onPressed: () => _loadData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadData(page: 1),
              decoration: InputDecoration(
                hintText: 'Tìm nhà thuốc...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _loadData(page: 1),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          _filterChips(),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: Colors.pink,
                ),
                const SizedBox(width: 8),
                Text(
                  '$title: $_total',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
              child: CircularProgressIndicator(
                color: Colors.pink,
              ),
            )
                : _rows.isEmpty
                ? const Center(
              child: Text('Không có dữ liệu phù hợp'),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final p = _rows[index];
                final img = p['image']?.toString() ?? '';
                final surveyed = _boolValue(p['is_surveyed']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showDetail(p),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: img.isEmpty
                                ? null
                                : () => _showImage(img),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: img.isEmpty
                                  ? Container(
                                width: 64,
                                height: 64,
                                color: surveyed
                                    ? const Color(0xFFDDFBE8)
                                    : const Color(0xFFFFF3D7),
                                child: Icon(
                                  surveyed
                                      ? Icons.verified
                                      : Icons.pending_actions,
                                  color: surveyed
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              )
                                  : Image.network(
                                _imageUrl(img),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    width: 64,
                                    height: 64,
                                    color:
                                    const Color(0xFFFFE4EE),
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.pink,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p['address']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _SurveyBadge(isSurveyed: surveyed),
                                if (surveyed) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    '👤 ${p['surveyed_by']?.toString().isNotEmpty == true ? p['surveyed_by'] : 'Chưa có người khảo sát'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    '🕒 ${p['surveyed_at'] ?? 'Chưa có thời gian'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (!_loading)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _page > 1
                        ? () => _loadData(page: _page - 1)
                        : null,
                    child: const Text('Trước'),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Trang $_page / $_totalPages'),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _page < _totalPages
                        ? () => _loadData(page: _page + 1)
                        : null,
                    child: const Text('Sau'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SurveyBadge extends StatelessWidget {
  final bool isSurveyed;

  const _SurveyBadge({
    required this.isSurveyed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSurveyed ? Colors.green : Colors.orange;
    final text = isSurveyed ? 'Đã khảo sát' : 'Chưa khảo sát';
    final icon = isSurveyed ? Icons.verified : Icons.pending_actions;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}