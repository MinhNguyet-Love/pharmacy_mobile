// import 'package:flutter/material.dart';
//
// import '../../../services/admin_service.dart';
//
// class AdminPharmaciesScreen extends StatefulWidget {
//   const AdminPharmaciesScreen({super.key});
//
//   @override
//   State<AdminPharmaciesScreen> createState() => _AdminPharmaciesScreenState();
// }
//
// class _AdminPharmaciesScreenState extends State<AdminPharmaciesScreen> {
//   final AdminService _adminService = AdminService();
//   final TextEditingController _searchController = TextEditingController();
//
//   List<Map<String, dynamic>> _rows = [];
//   bool _loading = true;
//   int _page = 1;
//   int _totalPages = 1;
//   int _total = 0;
//   bool _hasImage = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadPharmacies();
//   }
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadPharmacies({int? page}) async {
//     setState(() => _loading = true);
//
//     final data = await _adminService.getAdminPharmacies(
//       page: page ?? _page,
//       perPage: 20,
//       search: _searchController.text.trim(),
//       hasImage: _hasImage,
//     );
//
//     if (!mounted) return;
//
//     setState(() {
//       _rows = ((data['rows'] ?? []) as List)
//           .map((e) => Map<String, dynamic>.from(e as Map))
//           .toList();
//       _page = data['page'] ?? 1;
//       _totalPages = data['totalPages'] ?? 1;
//       _total = data['total'] ?? 0;
//       _loading = false;
//     });
//   }
//
//   Future<void> _deletePharmacy(Map<String, dynamic> p) async {
//     final id = int.tryParse(p['id'].toString()) ?? 0;
//     if (id == 0) return;
//
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Xoá nhà thuốc?'),
//         content: Text('Bạn có chắc muốn xoá "${p['name'] ?? ''}"?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Huỷ'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Xoá'),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm != true) return;
//
//     final ok = await _adminService.deleteAdminPharmacy(id);
//
//     if (!mounted) return;
//
//     if (ok) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Đã xoá nhà thuốc')),
//       );
//       _loadPharmacies();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Xoá thất bại')),
//       );
//     }
//   }
//
//   void _openEditSheet(Map<String, dynamic> p) {
//     final id = int.tryParse(p['id'].toString()) ?? 0;
//
//     final name = TextEditingController(text: p['name']?.toString() ?? '');
//     final address = TextEditingController(text: p['address']?.toString() ?? '');
//     final province = TextEditingController(text: p['province']?.toString() ?? '');
//     final district = TextEditingController(text: p['district']?.toString() ?? '');
//     final phone = TextEditingController(text: p['phone']?.toString() ?? '');
//     final status = TextEditingController(text: p['status']?.toString() ?? '');
//     final rating = TextEditingController(text: p['rating']?.toString() ?? '');
//     final image = TextEditingController(text: p['image']?.toString() ?? '');
//     final latitude =
//     TextEditingController(text: p['latitude']?.toString() ?? '');
//     final longitude =
//     TextEditingController(text: p['longitude']?.toString() ?? '');
//
//     bool saving = false;
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       showDragHandle: true,
//       builder: (_) {
//         return StatefulBuilder(
//           builder: (context, setSheetState) {
//             Future<void> save() async {
//               if (saving) return;
//
//               setSheetState(() => saving = true);
//
//               final ok = await _adminService.updateAdminPharmacy(
//                 id: id,
//                 name: name.text.trim(),
//                 address: address.text.trim(),
//                 province: province.text.trim(),
//                 district: district.text.trim(),
//                 phone: phone.text.trim(),
//                 status: status.text.trim(),
//                 rating: double.tryParse(rating.text.trim()),
//                 latitude: double.tryParse(latitude.text.trim()) ?? 0,
//                 longitude: double.tryParse(longitude.text.trim()) ?? 0,
//                 image: image.text.trim(),
//               );
//
//               if (!mounted) return;
//
//               setSheetState(() => saving = false);
//
//               if (ok) {
//                 Navigator.pop(context);
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Đã cập nhật nhà thuốc')),
//                 );
//                 _loadPharmacies();
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Cập nhật thất bại')),
//                 );
//               }
//             }
//
//             return Padding(
//               padding: EdgeInsets.fromLTRB(
//                 16,
//                 8,
//                 16,
//                 MediaQuery.of(context).viewInsets.bottom + 18,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   children: [
//                     const Text(
//                       'Sửa nhà thuốc',
//                       style:
//                       TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 14),
//                     _field('Tên nhà thuốc', name),
//                     _field('Địa chỉ', address, maxLines: 2),
//                     _field('Tỉnh / Thành phố', province),
//                     _field('Quận / Huyện', district),
//                     _field('Số điện thoại', phone),
//                     _field('Trạng thái', status),
//                     _field('Rating', rating,
//                         keyboardType:
//                         const TextInputType.numberWithOptions(decimal: true)),
//                     _field('Latitude', latitude,
//                         keyboardType:
//                         const TextInputType.numberWithOptions(decimal: true)),
//                     _field('Longitude', longitude,
//                         keyboardType:
//                         const TextInputType.numberWithOptions(decimal: true)),
//                     _field('Image URL', image, maxLines: 2),
//                     const SizedBox(height: 12),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 50,
//                       child: ElevatedButton.icon(
//                         onPressed: saving ? null : save,
//                         icon: saving
//                             ? const SizedBox(
//                           width: 18,
//                           height: 18,
//                           child:
//                           CircularProgressIndicator(strokeWidth: 2),
//                         )
//                             : const Icon(Icons.save),
//                         label: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   Widget _field(
//       String label,
//       TextEditingController controller, {
//         int maxLines = 1,
//         TextInputType? keyboardType,
//       }) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: TextField(
//         controller: controller,
//         maxLines: maxLines,
//         keyboardType: keyboardType,
//         decoration: InputDecoration(
//           labelText: label,
//           filled: true,
//           fillColor: const Color(0xFFF8FAFC),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: BorderSide.none,
//           ),
//         ),
//       ),
//     );
//   }
//
//   String _imageUrl(String image) {
//     if (image.startsWith('http')) return image;
//     if (image.startsWith('/uploads')) {
//       return 'https://pharmacy-backend-y6zm.onrender.com$image';
//     }
//     return image;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Quản lý Nhà thuốc'),
//         actions: [
//           IconButton(
//             onPressed: () => _loadPharmacies(),
//             icon: const Icon(Icons.refresh),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(14),
//             child: Column(
//               children: [
//                 TextField(
//                   controller: _searchController,
//                   textInputAction: TextInputAction.search,
//                   onSubmitted: (_) => _loadPharmacies(page: 1),
//                   decoration: InputDecoration(
//                     hintText: 'Tìm tên nhà thuốc...',
//                     prefixIcon: const Icon(Icons.search),
//                     suffixIcon: IconButton(
//                       icon: const Icon(Icons.send),
//                       onPressed: () => _loadPharmacies(page: 1),
//                     ),
//                     filled: true,
//                     fillColor: Colors.white,
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide: BorderSide.none,
//                     ),
//                   ),
//                 ),
//                 Row(
//                   children: [
//                     Checkbox(
//                       value: _hasImage,
//                       onChanged: (v) {
//                         setState(() => _hasImage = v ?? false);
//                         _loadPharmacies(page: 1);
//                       },
//                     ),
//                     const Text('Chỉ nhà thuốc có ảnh'),
//                     const Spacer(),
//                     Text('Tổng: $_total'),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: _loading
//                 ? const Center(child: CircularProgressIndicator())
//                 : _rows.isEmpty
//                 ? const Center(child: Text('Không có nhà thuốc'))
//                 : ListView.builder(
//               padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
//               itemCount: _rows.length,
//               itemBuilder: (context, index) {
//                 final p = _rows[index];
//                 final img = p['image']?.toString() ?? '';
//
//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         ClipRRect(
//                           borderRadius: BorderRadius.circular(12),
//                           child: img.isEmpty
//                               ? Container(
//                             width: 64,
//                             height: 64,
//                             color: const Color(0xFFFFE4EE),
//                             child: const Icon(
//                               Icons.local_pharmacy,
//                               color: Colors.pink,
//                             ),
//                           )
//                               : Image.network(
//                             _imageUrl(img),
//                             width: 64,
//                             height: 64,
//                             fit: BoxFit.cover,
//                             errorBuilder: (_, __, ___) =>
//                                 Container(
//                                   width: 64,
//                                   height: 64,
//                                   color: const Color(0xFFFFE4EE),
//                                   child: const Icon(
//                                     Icons.broken_image,
//                                     color: Colors.pink,
//                                   ),
//                                 ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment:
//                             CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 p['name']?.toString() ?? '',
//                                 maxLines: 2,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 p['address']?.toString() ?? '',
//                                 maxLines: 2,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: const TextStyle(fontSize: 12),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 '${p['province'] ?? ''} - ${p['district'] ?? ''}',
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.black54,
//                                 ),
//                               ),
//                               Row(
//                                 children: [
//                                   TextButton.icon(
//                                     onPressed: () =>
//                                         _openEditSheet(p),
//                                     icon: const Icon(Icons.edit,
//                                         size: 18),
//                                     label: const Text('Sửa'),
//                                   ),
//                                   TextButton.icon(
//                                     onPressed: () =>
//                                         _deletePharmacy(p),
//                                     icon: const Icon(
//                                       Icons.delete_outline,
//                                       size: 18,
//                                       color: Colors.red,
//                                     ),
//                                     label: const Text(
//                                       'Xoá',
//                                       style:
//                                       TextStyle(color: Colors.red),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           if (!_loading)
//             Container(
//               padding: const EdgeInsets.all(10),
//               color: Colors.white,
//               child: Row(
//                 children: [
//                   ElevatedButton(
//                     onPressed: _page > 1
//                         ? () => _loadPharmacies(page: _page - 1)
//                         : null,
//                     child: const Text('Trước'),
//                   ),
//                   Expanded(
//                     child: Center(
//                       child: Text('Trang $_page / $_totalPages'),
//                     ),
//                   ),
//                   ElevatedButton(
//                     // onPressed: _page < _totalPages
//                         ? () => _loadPharmacies(page: _page + 1)
//                         : null,
//                     child: const Text('Sau'),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';

import '../../../services/admin_service.dart';

class AdminPharmaciesScreen extends StatefulWidget {
  const AdminPharmaciesScreen({super.key});

  @override
  State<AdminPharmaciesScreen> createState() => _AdminPharmaciesScreenState();
}

class _AdminPharmaciesScreenState extends State<AdminPharmaciesScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  List<String> _provinces = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _hasImage = false;
  bool? _isSurveyed;
  String _selectedProvince = '';

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    _loadPharmacies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    final provinces = await _adminService.getProvinces();
    if (!mounted) return;
    setState(() => _provinces = provinces);
  }

  Future<void> _loadPharmacies({int? page}) async {
    setState(() => _loading = true);
    final data = await _adminService.getAdminPharmacies(
      page: page ?? _page,
      perPage: 20,
      search: _searchController.text.trim(),
      province: _selectedProvince,
      district: _districtController.text.trim(),
      hasImage: _hasImage,
      isSurveyed: _isSurveyed,
    );
    if (!mounted) return;
    setState(() {
      _rows = ((data['rows'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    if (image.startsWith('http')) return image;
    if (image.startsWith('/uploads')) return 'https://pharmacy-backend-y6zm.onrender.com$image';
    return image;
  }

  Future<void> _deletePharmacy(Map<String, dynamic> p) async {
    final id = int.tryParse(p['id'].toString()) ?? 0;
    if (id == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá nhà thuốc?'),
        content: Text('Bạn có chắc muốn xoá "${p['name'] ?? ''}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Xoá')),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await _adminService.deleteAdminPharmacy(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Đã xoá nhà thuốc' : 'Xoá thất bại')));
    if (ok) _loadPharmacies();
  }

  void _showDetail(Map<String, dynamic> p) {
    final img = p['image']?.toString() ?? '';
    final surveyed = _boolValue(p['is_surveyed']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (img.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(_imageUrl(img), height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              const SizedBox(height: 14),
              Text(p['name']?.toString() ?? '', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _SurveyBadge(isSurveyed: surveyed),
              const SizedBox(height: 14),
              _detail('Địa chỉ', p['address']),
              _detail('Tỉnh / Thành', p['province']),
              _detail('Quận / Huyện', p['district']),
              _detail('Số điện thoại', p['phone']),
              _detail('Trạng thái', p['status']),
              _detail('Rating', p['rating']),
              _detail('Thời gian khảo sát', p['surveyed_at']),
              _detail('Người khảo sát', p['surveyed_by'] ?? 'Chưa có dữ liệu'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _openEditSheet(p); }, icon: const Icon(Icons.edit), label: const Text('Sửa'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); _deletePharmacy(p); }, icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text('Xoá', style: TextStyle(color: Colors.red)))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _detail(String title, dynamic value) {
    final text = value?.toString() ?? '';
    return Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)), child: Text('$title: ${text.isEmpty ? 'Không có' : text}'));
  }


  void _openEditSheet(Map<String, dynamic> p) {
    final id = int.tryParse(p['id'].toString()) ?? 0;
    final name = TextEditingController(text: p['name']?.toString() ?? '');
    final address = TextEditingController(text: p['address']?.toString() ?? '');
    final province = TextEditingController(text: p['province']?.toString() ?? '');
    final district = TextEditingController(text: p['district']?.toString() ?? '');
    final phone = TextEditingController(text: p['phone']?.toString() ?? '');
    final status = TextEditingController(text: p['status']?.toString() ?? '');
    final rating = TextEditingController(text: p['rating']?.toString() ?? '');
    final image = TextEditingController(text: p['image']?.toString() ?? '');
    final latitude = TextEditingController(text: p['latitude']?.toString() ?? '');
    final longitude = TextEditingController(text: p['longitude']?.toString() ?? '');
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(builder: (context, setSheetState) {
        Future<void> save() async {
          if (saving) return;
          setSheetState(() => saving = true);
          final ok = await _adminService.updateAdminPharmacy(
            id: id,
            name: name.text.trim(),
            address: address.text.trim(),
            province: province.text.trim(),
            district: district.text.trim(),
            phone: phone.text.trim(),
            status: status.text.trim(),
            rating: double.tryParse(rating.text.trim()),
            latitude: double.tryParse(latitude.text.trim()) ?? 0,
            longitude: double.tryParse(longitude.text.trim()) ?? 0,
            image: image.text.trim(),
          );
          if (!mounted) return;
          setSheetState(() => saving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Đã cập nhật nhà thuốc' : 'Cập nhật thất bại')));
          if (ok) { Navigator.pop(context); _loadPharmacies(); }
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 18),
          child: SingleChildScrollView(
            child: Column(children: [
              const Text('Sửa nhà thuốc', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              _field('Tên nhà thuốc', name),
              _field('Địa chỉ', address, maxLines: 2),
              _field('Tỉnh / Thành phố', province),
              _field('Quận / Huyện', district),
              _field('Số điện thoại', phone),
              _field('Trạng thái', status),
              _field('Rating', rating, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              _field('Latitude', latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              _field('Longitude', longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              _field('Image URL', image, maxLines: 2),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'))),
            ]),
          ),
        );
      }),
    );
  }
  void _openCreateSheet() {
    final name = TextEditingController();
    final address = TextEditingController();
    final province = TextEditingController();
    final district = TextEditingController();
    final phone = TextEditingController();
    final status = TextEditingController(
      text: 'Đang hoạt động',
    );
    final rating = TextEditingController(
      text: '5',
    );
    final image = TextEditingController();
    final latitude = TextEditingController();
    final longitude = TextEditingController();

    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> save() async {
            if (saving) return;

            if (name.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Vui lòng nhập tên nhà thuốc',
                  ),
                ),
              );
              return;
            }

            final lat = double.tryParse(
              latitude.text.trim(),
            );

            final lng = double.tryParse(
              longitude.text.trim(),
            );

            if (lat == null || lng == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Latitude/Longitude không hợp lệ',
                  ),
                ),
              );
              return;
            }

            setSheetState(() => saving = true);

            final ok =
            await _adminService.createAdminPharmacy(
              name: name.text.trim(),
              address: address.text.trim(),
              province: province.text.trim(),
              district: district.text.trim(),
              phone: phone.text.trim(),
              status: status.text.trim(),
              rating: double.tryParse(
                rating.text.trim(),
              ),
              latitude: lat,
              longitude: lng,
              image: image.text.trim(),
            );

            if (!mounted) return;

            setSheetState(() => saving = false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? 'Đã thêm nhà thuốc'
                      : 'Thêm nhà thuốc thất bại',
                ),
              ),
            );

            if (ok) {
              Navigator.pop(context);

              _loadPharmacies(
                page: 1,
              );
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context)
                  .viewInsets
                  .bottom +
                  18,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text(
                    'Thêm nhà thuốc',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _field(
                    'Tên nhà thuốc',
                    name,
                  ),

                  _field(
                    'Địa chỉ',
                    address,
                    maxLines: 2,
                  ),

                  _field(
                    'Tỉnh / Thành phố',
                    province,
                  ),

                  _field(
                    'Quận / Huyện',
                    district,
                  ),

                  _field(
                    'Số điện thoại',
                    phone,
                  ),

                  _field(
                    'Trạng thái',
                    status,
                  ),

                  _field(
                    'Rating',
                    rating,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  _field(
                    'Latitude',
                    latitude,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  _field(
                    'Longitude',
                    longitude,
                    keyboardType:
                    const TextInputType
                        .numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  _field(
                    'Image URL',
                    image,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child:
                    ElevatedButton.icon(
                      onPressed:
                      saving ? null : save,
                      icon: saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(
                        Icons.add,
                      ),
                      label: Text(
                        saving
                            ? 'Đang thêm...'
                            : 'Thêm nhà thuốc',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _field(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(controller: controller, maxLines: maxLines, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
    );
  }

  void _resetFilter() {
    setState(() { _searchController.clear(); _districtController.clear(); _selectedProvince = ''; _hasImage = false; _isSurveyed = null; });
    _loadPharmacies(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Nhà thuốc'),
        actions: [
          IconButton(
            onPressed: _openCreateSheet,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: () => _loadPharmacies(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(children: [
        _FilterBox(),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator()) : _rows.isEmpty ? const Center(child: Text('Không có nhà thuốc')) : ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final p = _rows[index];
              final img = p['image']?.toString() ?? '';
              final surveyed = _boolValue(p['is_surveyed']);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showDetail(p),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: img.isEmpty ? Container(width: 64, height: 64, color: const Color(0xFFFFE4EE), child: const Icon(Icons.local_pharmacy, color: Colors.pink)) : Image.network(_imageUrl(img), width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: const Color(0xFFFFE4EE), child: const Icon(Icons.broken_image, color: Colors.pink)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(p['address']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        _SurveyBadge(isSurveyed: surveyed),
                        const SizedBox(height: 4),
                        Text('${p['province'] ?? ''} - ${p['district'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Row(children: [
                          TextButton.icon(onPressed: () => _showDetail(p), icon: const Icon(Icons.visibility_outlined, size: 18), label: const Text('Chi tiết')),
                          TextButton.icon(onPressed: () => _openEditSheet(p), icon: const Icon(Icons.edit, size: 18), label: const Text('Sửa')),
                          TextButton.icon(onPressed: () => _deletePharmacy(p), icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), label: const Text('Xoá', style: TextStyle(color: Colors.red))),
                        ]),
                      ])),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        if (!_loading) Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Row(children: [
          ElevatedButton(onPressed: _page > 1 ? () => _loadPharmacies(page: _page - 1) : null, child: const Text('Trước')),
          Expanded(child: Center(child: Text('Trang $_page / $_totalPages - Tổng $_total'))),
          ElevatedButton(
            onPressed: _page < _totalPages
                ? () => _loadPharmacies(page: _page + 1)
                : null,
            child: const Text('Sau'),
          ),
        ])),
      ]),
    );
  }

  Widget _FilterBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        TextField(controller: _searchController, textInputAction: TextInputAction.search, onSubmitted: (_) => _loadPharmacies(page: 1), decoration: InputDecoration(hintText: 'Tìm tên hoặc địa chỉ...', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: () => _loadPharmacies(page: 1)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: _selectedProvince.isEmpty ? null : _selectedProvince, isExpanded: true, decoration: InputDecoration(hintText: 'Tỉnh/TP', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)), items: [const DropdownMenuItem(value: '', child: Text('Tất cả tỉnh')), ..._provinces.map((e) => DropdownMenuItem(value: e, child: Text(e)))], onChanged: (v) { setState(() => _selectedProvince = v ?? ''); _loadPharmacies(page: 1); })),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _districtController, textInputAction: TextInputAction.search, onSubmitted: (_) => _loadPharmacies(page: 1), decoration: InputDecoration(hintText: 'Quận/Huyện', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)))),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          FilterChip(label: const Text('Có ảnh'), selected: _hasImage, onSelected: (v) { setState(() => _hasImage = v); _loadPharmacies(page: 1); }),
          ChoiceChip(label: const Text('Tất cả'), selected: _isSurveyed == null, onSelected: (_) { setState(() => _isSurveyed = null); _loadPharmacies(page: 1); }),
          ChoiceChip(label: const Text('Đã khảo sát'), selected: _isSurveyed == true, onSelected: (_) { setState(() => _isSurveyed = true); _loadPharmacies(page: 1); }),
          ChoiceChip(label: const Text('Chưa khảo sát'), selected: _isSurveyed == false, onSelected: (_) { setState(() => _isSurveyed = false); _loadPharmacies(page: 1); }),
          ActionChip(label: const Text('Xoá lọc'), onPressed: _resetFilter),
        ]),
      ]),
    );
  }
}

class _SurveyBadge extends StatelessWidget {
  final bool isSurveyed;
  const _SurveyBadge({required this.isSurveyed});

  @override
  Widget build(BuildContext context) {
    final color = isSurveyed ? Colors.green : Colors.orange;
    final text = isSurveyed ? 'Đã khảo sát' : 'Chưa khảo sát';
    final icon = isSurveyed ? Icons.verified : Icons.pending_actions;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 14), const SizedBox(width: 4), Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))]));
  }
}
