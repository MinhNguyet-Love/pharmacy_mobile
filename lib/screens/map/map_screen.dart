import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../camera/camera_capture_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/pharmacy_model.dart';
import '../../services/pharmacy_service.dart';
import '../../services/admin_service.dart';
import '../../services/survey_area_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class MapScreen extends StatefulWidget {
  final String role;

  const MapScreen({
    super.key,
    required this.role,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  final AdminService _adminService = AdminService();
  final SurveyAreaService _surveyAreaService = SurveyAreaService();
  final AuthService _authService = AuthService();

  final MapController _mapController = MapController();
  final ImagePicker _imagePicker = ImagePicker();

  List<String> _provinces = [];
  List<PharmacyModel> _allPharmacies = [];
  List<PharmacyModel> _pharmacies = [];
  List<PharmacyModel> _searchResults = [];
  List<Map<String, dynamic>> _provinceStats = [];
  List<WeightedLatLng> _heatPoints = [];

  String? _selectedProvince;

  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController(text: '5');

  int _totalPharmacyCount = 0;

  bool _isLoading = true;
  bool _isViewportLoading = false;
  bool _showSearchBar = false;
  bool _showSearchResults = false;
  bool _showHeatmap = false;
  bool _sortNearest = true;
  bool _showToolPanel = false;
  bool _isPickingArea = false;
  bool _isAreaFiltered = false;
  bool _markersEnabled = false;

  List<LatLng> _areaPoints = [];
  List<Map<String, dynamic>> _assignedAreas = [];
  Map<String, dynamic>? _selectedAssignedArea;
  Timer? _moveDebounce;
  LatLng? _myLocation;

  final LatLng _defaultCenter = const LatLng(16.0544, 108.2022);

  // --- Quyền hệ thống chỉnh sửa và các biến phân quyền ---
  bool get _canEdit =>
      widget.role == 'company' ||
          widget.role == 'admin' ||
          widget.role == 'company_staff';
  bool get _canViewAdvancedFeatures => widget.role == 'company' || widget.role == 'admin';
  bool get _canExport => widget.role == 'company' || widget.role == 'admin';

  bool get isCompany => widget.role == 'company';
  bool get isCompanyStaff => widget.role == 'company_staff';

  String get _roleLabel {
    switch (widget.role) {
      case 'admin':
        return 'ADMIN';
      case 'company':
        return 'COMPANY';
      case 'company_staff':
        return 'NHÂN VIÊN';
      default:
        return 'USER';
    }
  }

  Color get _roleColor {
    switch (widget.role) {
      case 'admin':
        return Colors.red;
      case 'company':
        return Colors.blue;
      case 'company_staff':
        return Colors.teal;
      default:
        return Colors.green;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  List<PharmacyModel> _takeSpread(List<PharmacyModel> source, int maxCount) {
    if (source.length <= maxCount) return source;

    final result = <PharmacyModel>[];
    final step = source.length / maxCount;

    for (int i = 0; i < maxCount; i++) {
      final index = (i * step).floor();
      result.add(source[index]);
    }

    return result;
  }

  // 1. Sửa đổi _loadInitialData() theo logic mới để tối ưu khởi tạo cho Nhân Viên
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      if (isCompanyStaff) {
        setState(() {
          _markersEnabled = true;
          _provinces = [];
          _totalPharmacyCount = 0;
          _allPharmacies = [];
          _pharmacies = [];
          _searchResults = [];
          _showSearchResults = false;
        });

        await _loadStaffAssignedArea();
        return;
      }

      final results = await Future.wait([
        _pharmacyService.getProvinces(),
        _pharmacyService.getPharmacyCount(),
      ]);

      final provinces = results[0] as List<String>;
      final total = results[1] as int;

      if (!mounted) return;

      setState(() {
        _provinces = provinces;
        _totalPharmacyCount = total;
        _markersEnabled = false;
        _allPharmacies = [];
        _pharmacies = [];
        _searchResults = [];
        _showSearchResults = false;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_defaultCenter, 5.6);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMsg('Không tải được dữ liệu ban đầu');
    }
  }

  // --- Logic tự động tải, khóa và lọc theo vùng được giao cho nhân viên thực địa ---
  // Future<void> _loadStaffAssignedArea() async {
  //   try {
  //     final areas = await _surveyAreaService.getAssignedSurveyAreasForStaff();
  //     if (areas.isEmpty) {
  //       setState(() => _isLoading = false);
  //       _showMsg('Tài khoản nhân viên chưa được giao vùng khảo sát nào.');
  //       return;
  //     }
  //
  //     // Lấy vùng khảo sát đầu tiên được giao
  //     final assignedArea = areas.first;
  //     final points = _surveyAreaService.parsePolygon(assignedArea['polygon']);
  //
  //     if (points.length < 3) {
  //       setState(() => _isLoading = false);
  //       _showMsg('Vùng khảo sát được giao không hợp lệ.');
  //       return;
  //     }
  //
  //     // Lấy toàn bộ danh sách nhà thuốc trong Bounding Box của vùng được giao
  //     final bbox = _bboxFromAreaPoints(points);
  //     final candidates = await _pharmacyService.getPharmaciesGeoJson(
  //       bbox: bbox,
  //       limit: 500, // 2. Giảm số lượng tối đa nhà thuốc cần tìm trong Bounding Box cho NV thực địa xuống 500
  //     );
  //
  //     // Lọc chính xác chỉ giữ lại các nhà thuốc nằm gọn trong Polygon vùng được giao
  //     final innerPharmacies = candidates.where((p) {
  //       if (p.lat == 0 || p.lng == 0) return false;
  //       return _pointInPolygon(LatLng(p.lat, p.lng), points);
  //     }).toList();
  //
  //     if (!mounted) return;
  //
  //     setState(() {
  //       _areaPoints = points;
  //       _allPharmacies = innerPharmacies;
  //       _pharmacies = innerPharmacies;
  //       _isPickingArea = false; // Khóa chức năng tự chọn/sửa vùng tự do
  //       _isAreaFiltered = true;
  //       _isLoading = false;
  //     });
  //
  //     // Tự động zoom fit camera khớp hoàn toàn vào vùng polygon được giao
  //     _fitMapToArea(points);
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     _showMsg('Lỗi tải vùng khảo sát nhân viên: $e');
  //   }
  // }
  // Future<void> _loadStaffAssignedArea() async {
  //   try {
  //     final areas =
  //     await _surveyAreaService.getAssignedSurveyAreasForStaff();
  //
  //     if (areas.isEmpty) {
  //       setState(() => _isLoading = false);
  //
  //       _showMsg(
  //         'Tài khoản nhân viên chưa được giao vùng khảo sát nào.',
  //       );
  //       return;
  //     }
  //
  //     List<LatLng> allPolygonPoints = [];
  //     List<PharmacyModel> allPharmacies = [];
  //
  //     for (final area in areas) {
  //       final points =
  //       _surveyAreaService.parsePolygon(area['polygon']);
  //
  //       if (points.length < 3) continue;
  //
  //       allPolygonPoints.addAll(points);
  //
  //       final bbox = _bboxFromAreaPoints(points);
  //
  //       final candidates =
  //       await _pharmacyService.getPharmaciesGeoJson(
  //         bbox: bbox,
  //         limit: 500,
  //       );
  //
  //       final filtered = candidates.where((p) {
  //         if (p.lat == 0 || p.lng == 0) return false;
  //
  //         return _pointInPolygon(
  //           LatLng(p.lat, p.lng),
  //           points,
  //         );
  //       }).toList();
  //
  //       allPharmacies.addAll(filtered);
  //     }
  //
  //     final uniqueMap = <int, PharmacyModel>{};
  //
  //     for (final p in allPharmacies) {
  //       uniqueMap[p.id] = p;
  //     }
  //
  //     final uniquePharmacies =
  //     uniqueMap.values.toList();
  //
  //     if (!mounted) return;
  //
  //     setState(() {
  //       _areaPoints = allPolygonPoints;
  //
  //       _allPharmacies = uniquePharmacies;
  //       _pharmacies = uniquePharmacies;
  //
  //       _isPickingArea = false;
  //       _isAreaFiltered = true;
  //       _isLoading = false;
  //     });
  //
  //     if (allPolygonPoints.isNotEmpty) {
  //       _fitMapToArea(allPolygonPoints);
  //     }
  //
  //     _showMsg(
  //       'Đã tải ${areas.length} vùng khảo sát (${uniquePharmacies.length} nhà thuốc)',
  //     );
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //
  //     _showMsg(
  //       'Lỗi tải vùng khảo sát nhân viên: $e',
  //     );
  //   }
  // }
  Future<void> _loadStaffAssignedArea() async {
    try {
      final areas = await _surveyAreaService.getAssignedSurveyAreasForStaff();

      if (areas.isEmpty) {
        setState(() => _isLoading = false);
        _showMsg('Tài khoản nhân viên chưa được giao vùng khảo sát nào.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _assignedAreas = areas;
        _isLoading = false;
      });

      if (areas.length == 1) {
        await _selectAssignedArea(areas.first);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAssignedAreasSelector();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg('Lỗi tải vùng khảo sát nhân viên: $e');
    }
  }
  Future<void> _selectAssignedArea(Map<String, dynamic> area) async {
    setState(() => _isLoading = true);

    try {
      final points = _surveyAreaService.parsePolygon(area['polygon']);

      if (points.length < 3) {
        setState(() => _isLoading = false);
        _showMsg('Vùng khảo sát không hợp lệ.');
        return;
      }

      final bbox = _bboxFromAreaPoints(points);

      final candidates = await _pharmacyService.getPharmaciesGeoJson(
        bbox: bbox,
        limit: 1000,
      );

      final filtered = candidates.where((p) {
        if (p.lat == 0 || p.lng == 0) return false;
        return _pointInPolygon(LatLng(p.lat, p.lng), points);
      }).toList();

      if (!mounted) return;

      setState(() {
        _selectedAssignedArea = area;
        _areaPoints = points;
        _allPharmacies = filtered;
        _pharmacies = filtered;
        _searchResults = [];
        _showSearchResults = false;
        _isPickingArea = false;
        _isAreaFiltered = true;
        _isLoading = false;
      });

      _fitMapToArea(points);
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg('Lỗi tải vùng đã chọn: $e');
    }
  }
  void _showAssignedAreasSelector() {
    if (_assignedAreas.isEmpty) {
      _showMsg('Không có vùng khảo sát được giao.');
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, color: Colors.teal),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vùng khảo sát được giao',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _assignedAreas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final area = _assignedAreas[index];

                      final id = area['id']?.toString() ?? '';
                      final name = area['name']?.toString() ??
                          'Vùng khảo sát ${index + 1}';

                      final selected =
                          _selectedAssignedArea?['id']?.toString() == id;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: selected
                            ? const Color(0xFFE0F2F1)
                            : const Color(0xFFF8FAFC),
                        leading: CircleAvatar(
                          backgroundColor:
                          selected ? Colors.teal : const Color(0xFF7C3AED),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          id.isEmpty ? 'Vùng được giao' : 'ID vùng: $id',
                        ),
                        trailing: Icon(
                          selected ? Icons.check_circle : Icons.chevron_right,
                          color: selected ? Colors.teal : Colors.black45,
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _selectAssignedArea(area);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _loadOverviewMarkers() async {
    if (_isViewportLoading || isCompanyStaff) return; // Khóa tải ngoài vùng đối với nhân viên

    try {
      _isViewportLoading = true;

      final pharmacies = await _pharmacyService.getPharmaciesGeoJson(
        bbox: '102.0,8.0,110.5,24.5',
        limit: 9000,
        mode: 'overview',
        ratingMin: double.tryParse(_ratingController.text.trim()),
      );

      if (!mounted) return;

      setState(() {
        _allPharmacies = pharmacies;
        _pharmacies = pharmacies;
        _searchResults = [];
        _showSearchResults = false;
      });
    } catch (e) {
      print('LOAD OVERVIEW ERROR: $e');
    } finally {
      _isViewportLoading = false;
    }
  }

  Future<void> _loadPharmaciesByViewport() async {
    if (_isViewportLoading) return;
    if (!_markersEnabled) return;
    if (isCompanyStaff) return; // Khóa tính năng tự động load theo khung nhìn viewport nếu là nhân viên

    final zoom = _mapController.camera.zoom;
    if (zoom < 8) {
      await _loadOverviewMarkers();
      return;
    }

    try {
      _isViewportLoading = true;

      final bounds = _mapController.camera.visibleBounds;
      final bbox = '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';

      int limit;
      if (zoom < 10) {
        limit = 5000;
      } else if (zoom < 13) {
        limit = 7000;
      } else if (zoom < 15) {
        limit = 9000;
      } else {
        limit = 11000;
      }

      final pharmacies = await _pharmacyService.getPharmaciesGeoJson(
        bbox: bbox,
        province: _selectedProvince,
        ratingMin: double.tryParse(_ratingController.text.trim()),
        limit: limit,
      );

      if (!mounted) return;

      final valid = pharmacies.where((p) {
        return p.id > 0 && p.lat != 0 && p.lng != 0;
      }).toList();

      setState(() {
        _allPharmacies = valid;
        _pharmacies = valid;
      });
    } catch (e) {
      print('LOAD VIEWPORT ERROR: $e');
    } finally {
      _isViewportLoading = false;
    }
  }

  String _safeImageUrl(String url) {
    final v = url.trim();
    if (v.isEmpty || v == 'N/A' || v == 'null') return '';
    if (v.startsWith('http')) return v;
    if (v.startsWith('/uploads')) {
      return 'https://pharmacy-backend-y6zm.onrender.com$v';
    }
    if (v.startsWith('uploads')) {
      return 'https://pharmacy-backend-y6zm.onrender.com/$v';
    }
    return v;
  }

  void _showMsg(String msg) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _pharmacyImageBox(String imageUrl) {
    final url = _safeImageUrl(imageUrl);

    if (url.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4EE),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_pharmacy, color: Color(0xFFE91E63), size: 48),
            SizedBox(height: 8),
            Text(
              'Chưa có ảnh nhà thuốc',
              style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4EE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const CircularProgressIndicator(color: Color(0xFFE91E63)),
          );
        },
        errorBuilder: (_, __, ___) {
          return Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4EE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.red, size: 42),
                SizedBox(height: 8),
                Text(
                  'Không tải được ảnh',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _requiredLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        children: const [
          TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _applyFilter() async {
    Navigator.pop(context);

    setState(() {
      _isLoading = true;
      _markersEnabled = true;
    });

    try {
      final ratingMin = double.tryParse(_ratingController.text.trim());

      final isAllProvince = _selectedProvince == null;

      final pharmaciesRaw = await _pharmacyService.getPharmaciesGeoJson(
        bbox: '102.0,8.0,110.5,24.5',
        province: _selectedProvince,
        ratingMin: ratingMin,
        limit: isAllProvince ? 9000 : 14000,
        mode: isAllProvince ? 'overview' : null,
      );

      if (!mounted) return;

      setState(() {
        _allPharmacies = pharmaciesRaw;
        _pharmacies = pharmaciesRaw;
        _searchResults = [];
        _showSearchResults = false;
        _showHeatmap = false;
        _isAreaFiltered = false;
        _isLoading = false;
      });

      if (_pharmacies.isNotEmpty) {
        _fitMapToMarkers(_pharmacies);
      } else {
        _showMsg('Không có nhà thuốc phù hợp');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMsg('Lọc dữ liệu thất bại');
    }
  }

  String _normalizeText(String input) {
    return input.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _searchPharmacy(String keyword) {
    final text = _normalizeText(keyword);

    if (text.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final results = _pharmacies.where((p) {
      final name = _normalizeText(p.name);
      final address = _normalizeText(p.address);
      final province = _normalizeText(p.province);
      final district = _normalizeText(p.district);

      return name.contains(text) ||
          address.contains(text) ||
          province.contains(text) ||
          district.contains(text);
    }).toList();

    setState(() {
      _searchResults = results;
      _showSearchResults = true;
    });
  }

  Future<void> _runSearch() async {
    FocusScope.of(context).unfocus();
    final keyword = _searchController.text.trim();

    if (keyword.isEmpty) {
      _showMsg('Bạn hãy nhập tên nhà thuốc hoặc địa chỉ cần tìm');
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    _searchPharmacy(keyword);

    if (_searchResults.length == 1) {
      _moveToPharmacy(_searchResults.first);
    } else if (_searchResults.length > 1) {
      _fitMapToMarkers(_searchResults);
    }
  }

  void _closeSearchBar() {
    setState(() {
      _showSearchBar = false;
      _searchController.clear();
      _searchResults = [];
      _showSearchResults = false;
    });
  }

  Future<void> _getMyLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMsg('Bạn chưa bật GPS / dịch vụ vị trí');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMsg('Bạn chưa cấp quyền vị trí');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMsg('Quyền vị trí đã bị chặn. Hãy mở Cài đặt để cấp quyền.');
        await Geolocator.openAppSettings();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;
      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
      });

      _mapController.move(_myLocation!, 15.5);
    } catch (e) {
      _showMsg('Không lấy được vị trí. Kiểm tra GPS/quyền vị trí.');
    }
  }

  double _distanceInKm(LatLng a, LatLng b) {
    const earthRadius = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final aa = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) * sin(dLng / 2) * sin(dLng / 2);

    final c = 2 * atan2(sqrt(aa), sqrt(1 - aa));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * pi / 180.0;

  String _bboxFromAreaPoints(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return '$minLng,$minLat,$maxLng,$maxLat';
  }

  Future<void> _filterInSelectedArea() async {
    if (_areaPoints.length < 3) {
      _showMsg('Cần chọn ít nhất 3 điểm để lọc vùng');
      return;
    }

    setState(() {
      _isLoading = true;
      _markersEnabled = true;
    });

    try {
      final bbox = _bboxFromAreaPoints(_areaPoints);

      final candidates = await _pharmacyService.getPharmaciesGeoJson(
        bbox: bbox,
        province: _selectedProvince,
        ratingMin: double.tryParse(_ratingController.text.trim()),
        limit: 9000,
      );

      final filtered = candidates.where((p) {
        if (p.lat == 0 || p.lng == 0) return false;
        return _pointInPolygon(LatLng(p.lat, p.lng), _areaPoints);
      }).toList();

      if (!mounted) return;

      setState(() {
        _allPharmacies = filtered;
        _pharmacies = filtered;
        _searchResults = filtered;
        _showSearchResults = true;
        _showHeatmap = false;
        _showToolPanel = false;
        _isPickingArea = false;
        _isAreaFiltered = true;
        _isLoading = false;
      });

      if (filtered.isNotEmpty) {
        _fitMapToMarkers(filtered);
        _showMsg('Đã lọc được ${filtered.length} nhà thuốc trong vùng');
      } else {
        _showMsg('Không tìm thấy nhà thuốc nào trong vùng đã chọn');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMsg('Lọc vùng thất bại');
    }
  }

  Future<void> _filterNearby() async {
    if (_myLocation == null) {
      await _getMyLocation();
      if (_myLocation == null) return;
    }

    setState(() {
      _isLoading = true;
      _markersEnabled = true;
    });

    try {
      final radiusKm = double.tryParse(_radiusController.text.trim()) ?? 5;
      final radiusDegree = radiusKm / 111.0;

      final bbox = '${_myLocation!.longitude - radiusDegree},'
          '${_myLocation!.latitude - radiusDegree},'
          '${_myLocation!.longitude + radiusDegree},'
          '${_myLocation!.latitude + radiusDegree}';

      var candidates = await _pharmacyService.getPharmaciesGeoJson(
        bbox: bbox,
        province: _selectedProvince,
        ratingMin: double.tryParse(_ratingController.text.trim()),
        limit: 9000,
        mode: null,
      );

      if (candidates.isEmpty) {
        candidates = await _pharmacyService.getPharmaciesGeoJson(
          bbox: '102.0,8.0,110.5,24.5',
          province: _selectedProvince,
          ratingMin: double.tryParse(_ratingController.text.trim()),
          limit: 15000,
          mode: null,
        );
      }

      final filtered = candidates.where((p) {
        if (p.lat == 0 || p.lng == 0) return false;

        final d = _distanceInKm(
          _myLocation!,
          LatLng(p.lat, p.lng),
        );

        return d <= radiusKm;
      }).toList();

      if (_sortNearest) {
        filtered.sort((a, b) {
          final da = _distanceInKm(_myLocation!, LatLng(a.lat, a.lng));
          final db = _distanceInKm(_myLocation!, LatLng(b.lat, b.lng));
          return da.compareTo(db);
        });
      }

      if (!mounted) return;

      setState(() {
        _allPharmacies = filtered;
        _pharmacies = filtered;
        _searchResults = filtered;
        _showSearchResults = true;
        _showHeatmap = false;
        _showToolPanel = false;
        _isLoading = false;
      });

      if (filtered.isNotEmpty) {
        _fitMapToMarkers(filtered);
        _showMsg('Đã tìm thấy ${filtered.length} nhà thuốc gần bạn');
      } else {
        _showMsg('Không có nhà thuốc nào trong bán kính $radiusKm km');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMsg('Lọc gần tôi thất bại');
    }
  }

  Future<void> _toggleHeatmap() async {
    if (!_canViewAdvancedFeatures) {
      _showMsg('Chỉ company hoặc admin mới dùng được heatmap');
      return;
    }

    if (_showHeatmap) {
      setState(() => _showHeatmap = false);
      return;
    }

    try {
      final ratingMin = double.tryParse(_ratingController.text.trim());
      final heatData = await _pharmacyService.getHeatmap(
        province: _selectedProvince,
        ratingMin: ratingMin,
      );

      final points = heatData.map((e) {
        final lat = (e['lat'] as num).toDouble();
        final lng = (e['lng'] as num).toDouble();
        return WeightedLatLng(LatLng(lat, lng), 1.0);
      }).toList();

      setState(() {
        _heatPoints = points;
        _showHeatmap = true;
        _showToolPanel = false;
      });
    } catch (e) {
      _showMsg('Không tải được heatmap. Kiểm tra API.');
    }
  }

  Future<void> _showProvinceStatsDialog() async {
    if (!_canViewAdvancedFeatures) {
      _showMsg('Chỉ company hoặc admin mới xem được thống kê');
      return;
    }

    try {
      if (_provinceStats.isEmpty) {
        _provinceStats = await _pharmacyService.getProvinceStats();
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: SizedBox(
              height: 520,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Thống kê theo tỉnh',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: _provinceStats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _provinceStats[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['province']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text('Tổng số: ${item['total'] ?? 0}'),
                              Text('Rating TB: ${item['avg_rating'] ?? '-'}'),
                              Text('Mở cửa: ${item['open_count'] ?? 0}'),
                              Text('Đóng cửa: ${item['closed_count'] ?? 0}'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Đóng'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showMsg('Không tải được thống kê theo tỉnh.');
    }
  }

  Future<void> _exportCsv() async {
    if (!_canExport) {
      _showMsg('Chỉ company hoặc admin mới được export CSV');
      return;
    }

    try {
      setState(() => _showToolPanel = false);
      final ok = await _adminService.exportCsv();
      if (ok) {
        _showMsg('Xuất CSV thành công');
      } else {
        _showMsg('Xuất CSV thất bại');
      }
    } catch (e) {
      _showMsg('Lỗi khi thực hiện export CSV');
    }
  }

  void _startPickArea() {
    setState(() {
      _isPickingArea = true;
      _isAreaFiltered = false;
      _showToolPanel = false;
      _areaPoints = [];
    });
    _showMsg('Chạm lên bản đồ để chọn các điểm tạo vùng');
  }

  void _undoAreaPoint() {
    if (_areaPoints.isEmpty) {
      _showMsg('Chưa có điểm nào');
      return;
    }
    setState(() => _areaPoints.removeLast());
  }

  void _clearArea() {
    setState(() {
      _isPickingArea = false;
      _isAreaFiltered = false;
      _areaPoints = [];
      _pharmacies = _allPharmacies;
      _searchResults = [];
      _showSearchResults = false;
    });
    _showMsg('Đã xoá vùng chọn');
  }

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / ((yj - yi) == 0 ? 0.0000001 : (yj - yi)) + xi);

      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }

  Future<void> _saveSelectedArea() async {
    if (_areaPoints.length < 3) {
      _showMsg('Cần chọn ít nhất 3 điểm để lưu vùng');
      return;
    }

    final controller = TextEditingController(
      text: 'Vùng khảo sát ${DateTime.now().millisecondsSinceEpoch}',
    );

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lưu vùng khảo sát'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tên vùng'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final ok = await _surveyAreaService.createSurveyArea(name: name, points: _areaPoints);
    _showMsg(ok ? 'Đã lưu vùng' : 'Không lưu được vùng');
  }

  void _fitMapToArea(List<LatLng> points) {
    if (points.length < 3) return;

    final bounds = LatLngBounds.fromPoints(points);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 260),
        ),
      );
    });
  }

  Future<void> _showMySurveyAreas() async {
    setState(() => _isLoading = true);

    final areas = await _surveyAreaService.getMySurveyAreas();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (areas.isEmpty) {
      _showMsg('Bạn chưa có vùng khảo sát nào');
      return;
    }

    _showAreasList(
      title: 'Vùng khảo sát của tôi',
      areas: areas,
      allowDelete: true,
      adminDelete: false,
    );
  }

  Future<void> _showAdminSurveyUsers() async {
    if (widget.role != 'admin') {
      _showMsg('Chỉ admin mới xem được vùng của user khác');
      return;
    }

    setState(() => _isLoading = true);
    final users = await _surveyAreaService.adminGetSurveyUsers();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (users.isEmpty) {
      _showMsg('Chưa có user nào lưu vùng khảo sát');
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = users[index];
              final userId = int.tryParse(user['user_id']?.toString() ?? user['id']?.toString() ?? '0') ?? 0;
              final fullname = user['fullname']?.toString() ?? user['name']?.toString() ?? 'User $userId';
              final email = user['email']?.toString() ?? '';

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: const Color(0xFFF8FAFC),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE91E63),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(fullname, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(email.isEmpty ? 'ID: $userId' : email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  if (userId == 0) {
                    _showMsg('Không lấy được ID user');
                    return;
                  }
                  Navigator.pop(context);

                  setState(() => _isLoading = true);
                  final areas = await _surveyAreaService.adminGetSurveyAreasByUser(userId);

                  if (!mounted) return;
                  setState(() => _isLoading = false);

                  if (areas.isEmpty) {
                    _showMsg('User này chưa có vùng khảo sát');
                    return;
                  }

                  _showAreasList(
                    title: 'Vùng của $fullname',
                    areas: areas,
                    allowDelete: true,
                    adminDelete: true,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showAreasList({
    required String title,
    required List<Map<String, dynamic>> areas,
    required bool allowDelete,
    required bool adminDelete,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: areas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final area = areas[index];
                    final id = int.tryParse(area['id']?.toString() ?? '0') ?? 0;
                    final name = area['name']?.toString() ?? 'Vùng khảo sát ${index + 1}';

                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFFF8FAFC),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF7C3AED),
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('ID vùng: $id'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Xem vùng',
                            icon: const Icon(Icons.visibility),
                            onPressed: () {
                              final points = _surveyAreaService.parsePolygon(area['polygon']);
                              if (points.length < 3) {
                                Navigator.pop(context);
                                _showMsg('Vùng này không có polygon hợp lệ');
                                return;
                              }
                              setState(() {
                                _areaPoints = points;
                                _isPickingArea = false;
                                _isAreaFiltered = false;
                                _showToolPanel = false;
                              });
                              Navigator.pop(context);
                              _fitMapToArea(points);
                            },
                          ),
                          if (allowDelete)
                            IconButton(
                              tooltip: 'Xoá vùng',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                if (id == 0) return;
                                Navigator.pop(context);

                                setState(() => _isLoading = true);
                                final ok = adminDelete
                                    ? await _surveyAreaService.adminDeleteSurveyArea(id)
                                    : await _surveyAreaService.deleteSurveyArea(id);

                                if (!mounted) return;
                                setState(() => _isLoading = false);

                                _showMsg(ok ? 'Đã xoá vùng' : 'Xoá vùng thất bại');
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _fitMapToMarkers(List<PharmacyModel> list) {
    final validList = list.where((p) => p.lat != 0 && p.lng != 0).toList();

    if (validList.isEmpty) {
      _mapController.move(_defaultCenter, 5.6);
      return;
    }

    if (validList.length == 1) {
      final p = validList.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(p.lat, p.lng), 16);
      });
      return;
    }

    double minLat = validList.first.lat;
    double maxLat = validList.first.lat;
    double minLng = validList.first.lng;
    double maxLng = validList.first.lng;

    for (final p in validList) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.fromLTRB(40, 90, 40, 260)),
      );
    });
  }

  void _moveToPharmacy(PharmacyModel p) {
    setState(() {
      _showSearchResults = false;
      _showToolPanel = false;
    });
    _mapController.move(LatLng(p.lat, p.lng), 17);
  }

  Future<void> _openDirections(PharmacyModel pharmacy) async {
    final lat = pharmacy.lat;
    final lng = pharmacy.lng;

    if (lat == 0 || lng == 0) {
      _showMsg('Nhà thuốc chưa có tọa độ hợp lệ');
      return;
    }

    final googleMapsApp = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleMapsWeb = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleMapsApp)) {
        await launchUrl(googleMapsApp, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showMsg('Không mở được chỉ đường');
    }
  }

  Future<void> _startFieldSurvey(PharmacyModel pharmacy) async {
    if (!_canEdit) {
      _showMsg('Chỉ company hoặc admin mới được khảo sát thực địa');
      return;
    }

    if (_myLocation == null) {
      await _getMyLocation();
    }

    if (_myLocation == null) {
      _showMsg('Bạn cần bật GPS để khảo sát thực địa');
      return;
    }

    final distanceKm = _distanceInKm(_myLocation!, LatLng(pharmacy.lat, pharmacy.lng));
    final distanceM = distanceKm * 1000;

    if (distanceM > 2000) {
      _showMsg('Bạn chưa tới đúng nhà thuốc. Khoảng cách hiện tại: ${distanceM.toStringAsFixed(1)}m');
      return;
    }

    _showMsg('Bạn đã tới ${pharmacy.name}, được phép chỉnh sửa thông tin');
    _openEditPharmacySheet(pharmacy);
  }

  // 2. Sửa hiển thị chi tiết nhà thuốc để hiển thị các trường dữ liệu thực địa mới bổ sung
  void _showPharmacyBottomSheet(PharmacyModel pharmacy) {
    final distanceText = _myLocation == null
        ? null
        : _distanceInKm(_myLocation!, LatLng(pharmacy.lat, pharmacy.lng)).toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pharmacyImageBox(pharmacy.imageUrl),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4EE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.medication_rounded, color: Color(0xFFE91E63), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pharmacy.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _surveyBadge(pharmacy.isSurveyed),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _detailItem(Icons.location_on_outlined, 'Địa chỉ', pharmacy.address),
                  _detailItem(Icons.map_outlined, 'Tỉnh / Thành', pharmacy.province),
                  _detailItem(Icons.account_balance_outlined, 'Quận / Huyện', pharmacy.district),
                  if (pharmacy.ward.isNotEmpty)
                    _detailItem(Icons.location_city_outlined, 'Phường / Xã', pharmacy.ward),
                  if (pharmacy.streetAddress.isNotEmpty)
                    _detailItem(
                      Icons.signpost_outlined,
                      'Số nhà / Đường / Thôn',
                      pharmacy.streetAddress,
                    ),
                  _detailItem(Icons.phone_outlined, 'Số điện thoại', pharmacy.phone.isEmpty ? 'Không có' : pharmacy.phone),
                  if (pharmacy.ownerName.isNotEmpty) _detailItem(Icons.person_outline, 'Chủ sở hữu', pharmacy.ownerName),
                  if (pharmacy.businessType.isNotEmpty)
                    _detailItem(
                      Icons.business_outlined,
                      'Hình thức',
                      pharmacy.businessType,
                    ),
                  _detailItem(Icons.star_outline, 'Rating', pharmacy.rating?.toString() ?? 'Không có'),
                  _detailItem(Icons.info_outline, 'Trạng thái', pharmacy.status.isEmpty ? 'Không có' : pharmacy.status),
                  if (pharmacy.productGroups.isNotEmpty) _detailItem(Icons.category_outlined, 'Nhóm sản phẩm', pharmacy.productGroups.join(', ')),
                  if (pharmacy.surveyNote.isNotEmpty)
                    _detailItem(
                      Icons.note_alt_outlined,
                      'Ghi chú khảo sát',
                      pharmacy.surveyNote,
                    ),
                  if (distanceText != null) _detailItem(Icons.near_me_outlined, 'Khoảng cách', '$distanceText km'),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _openDirections(pharmacy),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.directions),
                      label: const Text('Dẫn đường đến nhà thuốc', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_canEdit) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _startFieldSurvey(pharmacy);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE91E63),
                          side: const BorderSide(color: Color(0xFFE91E63)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.fact_check),
                        label: const Text('Khảo sát thực địa', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _surveyBadge(bool isSurveyed) {
    final bgColor = isSurveyed ? const Color(0xFF16A34A) : Colors.orange;
    final icon = isSurveyed ? Icons.verified_rounded : Icons.pending_actions;
    final text = isSurveyed ? 'Đã khảo sát' : 'Chưa khảo sát';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 1. Thay thế hoàn toàn hàm _openEditPharmacySheet() để tích hợp giao diện form khảo sát chuẩn hóa thực địa
  void _openEditPharmacySheet(PharmacyModel pharmacy) {
    final nameController = TextEditingController(text: pharmacy.name);
    final provinceController = TextEditingController(text: pharmacy.province);
    final districtController = TextEditingController(text: pharmacy.district);
    final wardController = TextEditingController(text: pharmacy.ward);
    final streetController = TextEditingController(
      text: pharmacy.streetAddress.isNotEmpty
          ? pharmacy.streetAddress
          : pharmacy.address,
    );
    final phoneController = TextEditingController(text: pharmacy.phone);
    final ownerNameController = TextEditingController(text: pharmacy.ownerName);
    final imageController = TextEditingController(text: pharmacy.imageUrl);
    final noteController = TextEditingController(text: pharmacy.surveyNote);

    String selectedStatus =
    pharmacy.status.trim().isNotEmpty ? pharmacy.status.trim() : 'Hoạt động';

    String selectedBusinessType = pharmacy.businessType.trim().isNotEmpty
        ? pharmacy.businessType.trim()
        : 'Tư nhân';

    double selectedRating = pharmacy.rating ?? 0;

    final List<String> productOptions = [
      'Giảm đau, hạ sốt',
      'Kháng sinh, kháng viêm',
      'Hô hấp (cảm cúm, ho)',
      'Tiêu hóa',
      'Huyết áp tim mạch',
      'Dị ứng',
      'Cơ xương khớp',
      'Nội tiết',
      'Thần kinh & tuần hoàn não',
      'Phụ khoa',
      'Vitamin và thực phẩm chức năng',
      'Sữa và sản phẩm từ sữa',
      'Vật tư y tế',
      'Dược mỹ phẩm',
      'Mẹ và bé',
      'Khác',
    ];

    List<String> selectedProducts = List<String>.from(pharmacy.productGroups);

    for (final item in selectedProducts) {
      if (!productOptions.contains(item)) {
        productOptions.add(item);
      }
    }

    File? pickedImageFile;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                FocusScope.of(context).unfocus();

                final picked = await _imagePicker.pickImage(
                  source: source,
                  imageQuality: 45,
                  maxWidth: 900,
                  maxHeight: 900,
                  preferredCameraDevice: CameraDevice.rear,
                );

                if (picked == null) return;

                final file = File(picked.path);

                if (!await file.exists()) {
                  _showMsg('Không tìm thấy ảnh vừa chụp');
                  return;
                }

                print('IMAGE PATH: ${file.path}');
                print('IMAGE SIZE: ${await file.length()}');

                setSheetState(() {
                  pickedImageFile = file;
                });
              } catch (e) {
                print('PICK IMAGE ERROR: $e');
                _showMsg('Lỗi camera: $e');
              }
            }

            Widget sectionTitle(String text, IconData icon) {
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  children: [
                    Icon(icon, color: const Color(0xFFE91E63), size: 19),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget optionChip({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                selectedColor: const Color(0xFFFFD6E7),
                checkmarkColor: const Color(0xFFE91E63),
                labelStyle: TextStyle(
                  color: selected ? const Color(0xFFE91E63) : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => onTap(),
              );
            }

            Future<void> saveUpdate() async {
              if (saving) return;

              final nameText = nameController.text.trim();
              final provinceText = provinceController.text.trim();
              final districtText = districtController.text.trim();
              final wardText = wardController.text.trim();
              final streetText = streetController.text.trim();
              final phoneText = phoneController.text.trim();
              final ownerNameText = ownerNameController.text.trim();
              final noteText = noteController.text.trim();

              if (nameText.isEmpty ||
                  provinceText.isEmpty ||
                  districtText.isEmpty ||
                  wardText.isEmpty ||
                  streetText.isEmpty ||
                  phoneText.isEmpty ||
                  ownerNameText.isEmpty ||
                  selectedStatus.isEmpty ||
                  selectedBusinessType.isEmpty ||
                  selectedProducts.isEmpty) {
                _showMsg('Bạn chưa nhập đủ thông tin bắt buộc');
                return;
              }

              if (phoneText.length < 9) {
                _showMsg('Số điện thoại không hợp lệ');
                return;
              }

              if (selectedRating < 0 || selectedRating > 5) {
                _showMsg('Số sao phải từ 0 đến 5');
                return;
              }

              if (_myLocation == null) {
                await _getMyLocation();
              }

              if (_myLocation == null) {
                _showMsg('Bạn cần bật GPS trước khi lưu khảo sát');
                return;
              }

              setSheetState(() => saving = true);

              try {
                String finalImageUrl = pharmacy.imageUrl;

                if (pickedImageFile != null) {
                  final uploadedUrl =
                  await _pharmacyService.uploadPharmacyImage(pickedImageFile!);

                  if (uploadedUrl == null || uploadedUrl.isEmpty) {
                    setSheetState(() => saving = false);
                    _showMsg('Upload ảnh thất bại');
                    return;
                  }

                  finalImageUrl = uploadedUrl;
                } else {
                  finalImageUrl = imageController.text.trim();
                }

                final updated = await _pharmacyService.updatePharmacy(
                  id: pharmacy.id,
                  name: nameText,
                  address: streetText,
                  province: provinceText,
                  district: districtText,
                  ward: wardText,
                  streetAddress: streetText,
                  phone: phoneText,
                  status: selectedStatus,
                  rating: selectedRating == 0 ? null : selectedRating,
                  imageUrl: finalImageUrl,
                  productGroups: selectedProducts,
                  ownerName: ownerNameText,
                  businessType: selectedBusinessType,
                  surveyNote: noteText,
                );

                if (!mounted) return;

                setSheetState(() => saving = false);

                if (updated != null) {
                  Navigator.pop(context);
                  _showMsg('Khảo sát nhà thuốc thành công');

                  if (isCompanyStaff) {
                    await _loadStaffAssignedArea();
                  } else {
                    await _loadPharmaciesByViewport();
                  }
                } else {
                  _showMsg('Lưu khảo sát thất bại');
                }
              } catch (e) {
                setSheetState(() => saving = false);
                _showMsg('Lỗi lưu khảo sát: $e');
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                8,
                18,
                MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phiếu khảo sát nhà thuốc',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Cập nhật thông tin thực địa của nhà thuốc',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    sectionTitle('Thông tin cơ bản', Icons.local_pharmacy),

                    _editField(
                      'Tên nhà thuốc',
                      nameController,
                      required: true,
                    ),

                    _editField(
                      'Tỉnh / Thành phố',
                      provinceController,
                      required: true,
                    ),

                    _editField(
                      'Quận / Huyện',
                      districtController,
                      required: true,
                    ),

                    _editField(
                      'Phường / Xã',
                      wardController,
                      required: true,
                    ),

                    _editField(
                      'Số nhà / Đường / Thôn',
                      streetController,
                      maxLines: 2,
                      required: true,
                    ),

                    _editField(
                      'Điện thoại',
                      phoneController,
                      keyboardType: TextInputType.phone,
                      required: true,
                    ),

                    _editField(
                      'Người phụ trách',
                      ownerNameController,
                      required: true,
                    ),

                    sectionTitle('Số sao đánh giá', Icons.star),

                    Row(
                      children: List.generate(5, (index) {
                        final star = index + 1;

                        return IconButton(
                          onPressed: () {
                            setSheetState(() {
                              selectedRating = star.toDouble();
                            });
                          },
                          icon: Icon(
                            Icons.star_rounded,
                            size: 34,
                            color: star <= selectedRating
                                ? Colors.amber
                                : Colors.grey.shade300,
                          ),
                        );
                      }),
                    ),

                    if (selectedRating > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          '${selectedRating.toStringAsFixed(0)} sao',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),

                    sectionTitle('Hình thức nhà thuốc', Icons.business),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        optionChip(
                          label: 'Tư nhân',
                          selected: selectedBusinessType == 'Tư nhân',
                          onTap: () {
                            setSheetState(() {
                              selectedBusinessType = 'Tư nhân';
                            });
                          },
                        ),
                        optionChip(
                          label: 'Công ty',
                          selected: selectedBusinessType == 'Công ty',
                          onTap: () {
                            setSheetState(() {
                              selectedBusinessType = 'Công ty';
                            });
                          },
                        ),
                        optionChip(
                          label: 'Thuộc BV',
                          selected: selectedBusinessType == 'Thuộc BV',
                          onTap: () {
                            setSheetState(() {
                              selectedBusinessType = 'Thuộc BV';
                            });
                          },
                        ),
                      ],
                    ),

                    sectionTitle('Trạng thái hoạt động', Icons.info_outline),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        optionChip(
                          label: 'Hoạt động',
                          selected: selectedStatus == 'Hoạt động',
                          onTap: () {
                            setSheetState(() {
                              selectedStatus = 'Hoạt động';
                            });
                          },
                        ),
                        optionChip(
                          label: 'Ngưng hoạt động',
                          selected: selectedStatus == 'Ngưng hoạt động',
                          onTap: () {
                            setSheetState(() {
                              selectedStatus = 'Ngưng hoạt động';
                            });
                          },
                        ),
                      ],
                    ),

                    sectionTitle('Hình ảnh nhà thuốc', Icons.image),

                    if (pickedImageFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          pickedImageFile!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 700,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                        ),
                      )
                    else
                      _pharmacyImageBox(imageController.text),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Chọn ảnh'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            // onPressed: () => pickImage(ImageSource.camera),
                            onPressed: () async {
                              final file = await Navigator.push<File?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CameraCaptureScreen(),
                                ),
                              );

                              if (file == null) return;

                              setSheetState(() {
                                pickedImageFile = file;
                              });
                            },
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Chụp ảnh'),
                          ),
                        ),
                      ],
                    ),

                    sectionTitle('Nhóm sản phẩm kinh doanh', Icons.category),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: productOptions.map((product) {
                        final checked = selectedProducts.contains(product);

                        return FilterChip(
                          label: Text(product),
                          selected: checked,
                          selectedColor: const Color(0xFFFFD6E7),
                          checkmarkColor: const Color(0xFFE91E63),
                          onSelected: (value) {
                            setSheetState(() {
                              if (value) {
                                selectedProducts.add(product);
                              } else {
                                selectedProducts.remove(product);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    sectionTitle('Ghi chú khảo sát', Icons.note_alt_outlined),

                    _editField(
                      'Ghi chú',
                      noteController,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : saveUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.save),
                        label: Text(
                          saving ? 'Đang lưu khảo sát...' : 'Lưu khảo sát',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _editField(
      String label,
      TextEditingController controller, {
        int maxLines = 1,
        TextInputType? keyboardType,
        bool required = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          label: required ? _requiredLabel(label) : Text(label),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFE91E63)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Không có' : value,
                  style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bộ lọc dữ liệu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                  const Text('Tỉnh / Thành phố', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: '-- Tất cả --',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('-- Tất cả --')),
                      ..._provinces.map((province) => DropdownMenuItem<String>(value: province, child: Text(province))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedProvince = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Rating tối thiểu', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ratingController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'VD: 4.0',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Áp dụng bộ lọc', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedProvince = null;
                          _ratingController.clear();
                          _markersEnabled = false;
                          _allPharmacies = [];
                          _pharmacies = [];
                          _searchResults = [];
                          _showHeatmap = false;
                          _showSearchResults = false;
                          _isAreaFiltered = false;
                        });
                        Navigator.pop(context);
                        _mapController.move(_defaultCenter, 5.6);
                      },
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Xóa bộ lọc'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _fitAssignedAreaAgain() {
    if (_areaPoints.isNotEmpty) {
      _fitMapToArea(_areaPoints);
    } else {
      _showMsg('Không tìm thấy dữ liệu vùng được giao.');
    }
  }

  Future<void> _logoutStaff() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _authService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  // Yêu cầu 1: Thêm hàm danh sách nhà thuốc cần khảo sát ngay dưới _fitAssignedAreaAgain()
  void _showAssignedPharmaciesList() {
    final needSurvey = _pharmacies.where((p) => !p.isSurveyed).toList();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.local_pharmacy, color: Colors.pink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nhà thuốc cần khảo sát (${needSurvey.length})',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: needSurvey.isEmpty
                    ? const Center(
                  child: Text(
                    'Tất cả nhà thuốc trong vùng đã được khảo sát',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: needSurvey.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = needSurvey[index];

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: const Color(0xFFF8FAFC),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFE4EE),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Color(0xFFE91E63),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        p.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);

                        _mapController.move(
                          LatLng(p.lat, p.lng),
                          17,
                        );
                        _showPharmacyBottomSheet(p);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Marker> _buildMarkers() {
    final validPharmacies = _pharmacies.where((p) => p.lat != 0 && p.lng != 0).toList();

    final markers = validPharmacies.map((pharmacy) {
      return Marker(
        point: LatLng(pharmacy.lat, pharmacy.lng),
        width: pharmacy.isSurveyed ? 34 : 26,
        height: pharmacy.isSurveyed ? 34 : 26,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _moveToPharmacy(pharmacy);
            _showPharmacyBottomSheet(pharmacy);
          },
          child: _buildCapsuleMarker(pharmacy),
        ),
      );
    }).toList();

    for (int i = 0; i < _areaPoints.length; i++) {
      markers.add(
        Marker(
          point: _areaPoints[i],
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    }

    if (_myLocation != null) {
      markers.insert(
        0,
        Marker(
          point: _myLocation!,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.16), shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _buildCapsuleMarker(PharmacyModel pharmacy) {
    final isSurveyed = pharmacy.isSurveyed;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: isSurveyed
                  ? const [Color(0xFF16A34A), Color(0xFF4ADE80)]
                  : const [Color(0xFFE91E63), Color(0xFFFF7AAE)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 1, offset: Offset(0, 0))],
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Center(
            child: Icon(
              isSurveyed ? Icons.check_rounded : Icons.medication_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        if (isSurveyed)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: const Color(0xFF15803D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 5.6,
        minZoom: 4,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onTap: (tapPosition, point) {
          if (!_isPickingArea || isCompanyStaff) return; // Khóa tương tác bản đồ nếu là nhân viên
          setState(() {
            _areaPoints.add(point);
          });
        },
        onPositionChanged: (position, hasGesture) {
          if (!hasGesture) return;
          if (isCompanyStaff) return; // Nhân viên không cho tự load lại viewport bừa bãi ngoài vùng
          _moveDebounce?.cancel();
          _moveDebounce = Timer(const Duration(milliseconds: 1200), () {
            _loadPharmaciesByViewport();
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.pharmacy_mobile',
          tileDisplay: const TileDisplay.fadeIn(),
          panBuffer: 1,
          keepBuffer: 2,
          maxNativeZoom: 19,
        ),
        if (_areaPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _areaPoints.length >= 3 ? [..._areaPoints, _areaPoints.first] : _areaPoints,
                strokeWidth: 3,
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
        if (_areaPoints.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: _areaPoints,
                color: const Color(0x557C3AED),
                borderColor: const Color(0xFF7C3AED),
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (_showHeatmap && _heatPoints.isNotEmpty)
          HeatMapLayer(
            heatMapDataSource: InMemoryHeatMapDataSource(data: _heatPoints),
            heatMapOptions: HeatMapOptions(minOpacity: 0.3, radius: 18),
          ),

        // 3. Tắt cluster layer cho tài khoản nhân viên (load MarkerLayer trực tiếp) để tăng tốc xử lý bản đồ vùng giao
        if (isCompanyStaff)
          MarkerLayer(
            markers: _buildMarkers(),
          )
        else
          RepaintBoundary(
            child: MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 110,
                disableClusteringAtZoom: 16,
                size: const Size(34, 34),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(60),
                markers: _buildMarkers(),
                builder: (context, markers) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        markers.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  );
                },
                onClusterTap: (cluster) async {
                  final nextZoom = min(_mapController.camera.zoom + 1.5, 16.0);
                  _mapController.move(cluster.bounds.center, nextZoom);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      child: Material(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildTopTitle() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 62,
      right: 82,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Text(
          isCompanyStaff ? 'Vùng khảo sát được giao' : 'Bản đồ nhà thuốc',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _searchPharmacy,
                onSubmitted: (_) => _runSearch(),
                decoration: const InputDecoration(
                  hintText: 'Tìm nhà thuốc, địa chỉ, tỉnh...',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(onPressed: _runSearch, icon: const Icon(Icons.search, size: 21), splashRadius: 20),
            IconButton(onPressed: _closeSearchBar, icon: const Icon(Icons.close, size: 21), splashRadius: 20),
          ],
        ),
      ),
    );
  }

  // Yêu cầu 2: Thay thế toàn bộ nội dung của _buildTopRightControls() để hỗ trợ phân quyền PopupMenuButton cho nhân viên
  Widget _buildTopRightControls() {
    if (isCompanyStaff) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 56,
        right: 12,
        child: PopupMenuButton<String>(
          offset: const Offset(-8, 42),
          color: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          onSelected: (value) async {
            if (value == 'location') {
              await _getMyLocation();
            }

            // if (value == 'area') {
            //   _fitAssignedAreaAgain();
            // }
            if (value == 'area') {
              _showAssignedAreasSelector();
            }

            if (value == 'pharmacies') {
              _showAssignedPharmaciesList();
            }

            if (value == 'logout') {
              await _logoutStaff();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'location',
              height: 38,
              child: Row(
                children: [
                  Icon(Icons.my_location, size: 17, color: Colors.blue),
                  SizedBox(width: 10),
                  Text(
                    'Lấy vị trí',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'area',
              height: 38,
              child: Row(
                children: [
                  Icon(Icons.map_outlined, size: 17, color: Colors.teal),
                  SizedBox(width: 10),
                  Text(
                    'Vùng khảo sát',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pharmacies',
              height: 38,
              child: Row(
                children: [
                  Icon(Icons.local_pharmacy_outlined, size: 17, color: Colors.pink),
                  SizedBox(width: 10),
                  Text(
                    'Nhà thuốc cần khảo sát',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              height: 38,
              child: Row(
                children: [
                  Icon(Icons.logout, size: 17, color: Colors.red),
                  SizedBox(width: 10),
                  Text(
                    'Đăng xuất',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, color: Colors.teal, size: 14),
                SizedBox(width: 4),
                Text(
                  'NHÂN VIÊN',
                  style: TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 58,
      right: 10,
      child: Column(
        children: [
          _buildCompactRoleBadge(),
          const SizedBox(height: 8),
          _buildRoundButton(
            icon: Icons.search,
            onTap: () {
              setState(() {
                _showSearchBar = true;
                _showToolPanel = false;
                _showSearchResults = false;
              });
            },
          ),
          const SizedBox(height: 8),
          _buildRoundButton(
            icon: Icons.filter_alt_outlined,
            onTap: () {
              setState(() => _showToolPanel = false);
              _openFilterSheet();
            },
          ),
          const SizedBox(height: 8),
          _buildRoundButton(
            icon: _showToolPanel ? Icons.close : Icons.menu,
            onTap: () {
              setState(() {
                _showToolPanel = !_showToolPanel;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withOpacity(0.96),
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: const Color(0xFF222222)),
        ),
      ),
    );
  }

  Widget _buildCompactRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: _roleColor, size: 15),
          const SizedBox(width: 5),
          Text(
            _roleLabel,
            style: TextStyle(color: _roleColor, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = min(screenWidth * 0.78, 310.0);

    return Positioned(
      left: 12,
      top: MediaQuery.of(context).padding.top + 82,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 210),
        curve: Curves.easeOut,
        offset: _showToolPanel ? Offset.zero : const Offset(-1.05, 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 170),
          opacity: _showToolPanel ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_showToolPanel,
            child: Container(
              width: panelWidth,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.64),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 8))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Công cụ hiển thị', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      'Quyền hiện tại: $_roleLabel',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _roleColor, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    if (_canViewAdvancedFeatures) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _showToolPanel = false);
                            _showProvinceStatsDialog();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3E8BE8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.local_hospital, size: 18),
                          label: const Text(
                            'Xem thông tin khu vực',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, height: 1.1, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _toggleHeatmap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: Icon(_showHeatmap ? Icons.layers_clear : Icons.local_fire_department, size: 16),
                          label: Text(
                            _showHeatmap ? 'Tắt heatmap' : 'Xem heatmap',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 2. Ẩn panel chọn vùng nếu là nhân viên thực địa
                    if (isCompany && !isCompanyStaff) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _startPickArea,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.polyline, size: 18),
                          label: Text(
                            _isPickingArea ? 'Đang chọn vùng' : 'Chọn vùng',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _showMySurveyAreas,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Vùng đã lưu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    if (widget.role == 'admin') ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _showAdminSurveyUsers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9333EA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.manage_accounts, size: 18),
                          label: const Text('Vùng user', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    if (_areaPoints.isNotEmpty && !isCompanyStaff) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _undoAreaPoint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Xoá điểm cuối'),
                        ),
                      ),
                    ],
                    if (_areaPoints.length >= 3 && !isCompanyStaff) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _filterInSelectedArea,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.filter_alt, size: 18),
                          label: const Text('Lọc trong vùng'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _saveSelectedArea,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('Lưu vùng'),
                        ),
                      ),
                    ],
                    if ((_areaPoints.isNotEmpty || _isAreaFiltered) && !isCompanyStaff) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _clearArea,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          label: const Text('Xoá vùng'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // 5. Khối Lấy vị trí GPS (Giữ lại duy nhất nút này cho Nhân Viên)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: _getMyLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4FCB79),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.my_location, size: 18),
                              label: const Text('Lấy vị trí', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        if (!isCompanyStaff) const SizedBox(width: 8),
                        if (!isCompanyStaff)
                          SizedBox(
                            width: 82,
                            child: TextField(
                              controller: _radiusController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '5',
                                suffixText: ' km',
                                suffixStyle: const TextStyle(fontSize: 12),
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // 3. Ẩn lọc gần tôi nếu là nhân viên
                    if (!isCompanyStaff) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _filterNearby,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.near_me, size: 18),
                          label: const Text('Lọc gần tôi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Transform.scale(
                            scale: 0.75,
                            child: Checkbox(
                              value: _sortNearest,
                              onChanged: (v) {
                                setState(() {
                                  _sortNearest = v ?? true;
                                });
                              },
                            ),
                          ),
                          const Expanded(
                            child: Text('Sắp xếp gần nhất', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                    if (_canExport) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _exportCsv,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6F42C1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Export CSV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.black54, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _myLocation == null ? 'Chưa lấy được vị trí' : 'Đã lấy vị trí hiện tại',
                              style: TextStyle(
                                color: _myLocation == null ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultPanel() {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.36, minHeight: 120),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(99)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kết quả (${_searchResults.length})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showSearchResults = false;
                      });
                    },
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFFE91E63)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _searchResults.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(18), child: Text('Không tìm thấy nhà thuốc phù hợp')))
                  : ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final p = _searchResults[index];
                  final distanceText = _myLocation == null
                      ? null
                      : _distanceInKm(_myLocation!, LatLng(p.lat, p.lng)).toStringAsFixed(2);

                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.isSurveyed ? const Color(0xFFDDFBE8) : const Color(0xFFFFE4EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        p.isSurveyed ? Icons.check_rounded : Icons.medication_rounded,
                        color: p.isSurveyed ? const Color(0xFF16A34A) : const Color(0xFFE91E63),
                        size: 19,
                      ),
                    ),
                    title: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      distanceText == null ? p.address : '${p.address}\nCách $distanceText km',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      _moveToPharmacy(p);
                      _showPharmacyBottomSheet(p);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      ),
    );
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _ratingController.dispose();
    _searchController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: _buildLoadingOverlay());
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          if (_showToolPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showToolPanel = false;
                  });
                },
                child: Container(color: Colors.black.withOpacity(0.08)),
              ),
            ),
          if (!_showSearchBar) _buildBackButton(),
          if (!_showSearchBar) _buildTopTitle(),

          // 4. Ẩn searchbox hoàn toàn cho nhân viên thực địa
          if (_showSearchBar && !isCompanyStaff) _buildSearchBox(),

          _buildTopRightControls(),

          // Thêm nút tắt nhanh vùng chọn (nút đỏ) ngay dưới _buildTopRightControls
          // Ẩn luôn cho role nhân viên để tránh họ tắt nhầm vùng được giao cứng
          if (_areaPoints.isNotEmpty && !isCompanyStaff)
            Positioned(
              top: MediaQuery.of(context).padding.top + 58,
              right: 62,
              child: Material(
                color: Colors.red,
                borderRadius: BorderRadius.circular(14),
                elevation: 4,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _areaPoints.clear();
                      _isPickingArea = false;
                      _isAreaFiltered = false;
                      _pharmacies = _allPharmacies;
                      _showSearchResults = false;
                    });
                    _showMsg('Đã tắt vùng chọn');
                  },
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

          // Yêu cầu 3: Kiểm tra trong build(), chỉ hiển thị Panel nếu không phải nhân viên thực địa
          if (!isCompanyStaff) _buildToolPanel(),
          if (_showSearchResults) _buildSearchResultPanel(),
        ],
      ),
    );
  }
}