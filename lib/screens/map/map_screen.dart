import 'dart:async';
import 'dart:io';
import 'dart:math';

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

  Timer? _moveDebounce;
  LatLng? _myLocation;

  final LatLng _defaultCenter = const LatLng(16.0544, 108.2022);

  bool get _canEdit => widget.role == 'company' || widget.role == 'admin';

  bool get _canViewAdvancedFeatures => widget.role == 'company' || widget.role == 'admin';

  bool get _canExport => widget.role == 'company' || widget.role == 'admin';

  String get _roleLabel {
    switch (widget.role) {
      case 'admin':
        return 'ADMIN';
      case 'company':
        return 'COMPANY';
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

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _pharmacyService.getProvinces(),
        _pharmacyService.getPharmacyCount(),
        _pharmacyService.getPharmaciesGeoJson(
          bbox: '102.0,8.0,110.5,24.5',
          limit: 5000,
          mode: 'overview',
        ),
      ]);

      final provinces = results[0] as List<String>;
      final total = results[1] as int;
      final pharmacies = results[2] as List<PharmacyModel>;

      if (!mounted) return;

      setState(() {
        _provinces = provinces;
        _totalPharmacyCount = total;
        _allPharmacies = pharmacies;
        _pharmacies = pharmacies;
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
      _showMsg('Không tải được dữ liệu bản đồ. Kiểm tra backend/API.');
    }
  }

  Future<void> _loadOverviewMarkers() async {
    if (_isViewportLoading) return;

    try {
      _isViewportLoading = true;

      final pharmacies = await _pharmacyService.getPharmaciesGeoJson(
        bbox: '102.0,8.0,110.5,24.5',
        limit: 5000,
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
        limit = 3800;
      } else if (zoom < 13) {
        limit = 4000;
      } else if (zoom < 15) {
        limit = 5000;
      } else {
        limit = 6000;
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

  Future<void> _applyFilter() async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final ratingMin = double.tryParse(_ratingController.text.trim());

      final pharmaciesRaw = await _pharmacyService.getPharmaciesGeoJson(
        bbox: '102.0,8.0,110.5,24.5',
        province: _selectedProvince,
        ratingMin: ratingMin,
        limit: 6000,
        mode: _selectedProvince == null ? 'overview' : null,
      );

      final pharmacies = _takeSpread(pharmaciesRaw, 5000);

      if (!mounted) return;

      setState(() {
        _allPharmacies = pharmacies;
        _pharmacies = pharmacies;
        _searchResults = [];
        _showSearchResults = false;
        _showHeatmap = false;
        _isLoading = false;
      });

      _fitMapToMarkers(_pharmacies);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMsg('Lọc dữ liệu thất bại. Kiểm tra API /pharmacies.geojson.');
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
      });

      _mapController.move(_myLocation!, 15.5);
      _showMsg('Đã lấy vị trí hiện tại');
    } catch (e) {
      _showMsg('Không lấy được vị trí. Kiểm tra GPS/quyền vị trí.');
    }
  }

  double _distanceInKm(LatLng a, LatLng b) {
    const earthRadius = 6371.0;

    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final aa = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(a.latitude)) *
            cos(_deg2rad(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(aa), sqrt(1 - aa));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * pi / 180.0;

  Future<void> _filterNearby() async {
    if (_myLocation == null) {
      await _getMyLocation();
      if (_myLocation == null) return;
    }

    final radiusKm = double.tryParse(_radiusController.text.trim()) ?? 5;
    final radiusDegree = radiusKm / 111.0;

    final bbox = '${_myLocation!.longitude - radiusDegree},'
        '${_myLocation!.latitude - radiusDegree},'
        '${_myLocation!.longitude + radiusDegree},'
        '${_myLocation!.latitude + radiusDegree}';

    final candidates = await _pharmacyService.getPharmaciesGeoJson(
      bbox: bbox,
      province: _selectedProvince,
      ratingMin: double.tryParse(_ratingController.text.trim()),
      limit: 3000,
    );

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

    if (filtered.isEmpty) {
      _showMsg('Không có nhà thuốc nào trong bán kính $radiusKm km');
      return;
    }

    setState(() {
      _pharmacies = filtered;
      _searchResults = filtered;
      _showSearchResults = true;
      _showHeatmap = false;
      _showToolPanel = false;
    });

    _fitMapToMarkers(filtered);
    _showMsg('Đã tìm thấy ${filtered.length} nhà thuốc gần bạn');
  }

  Future<void> _toggleHeatmap() async {
    if (!_canViewAdvancedFeatures) {
      _showMsg('Chỉ company hoặc admin mới dùng được heatmap');
      return;
    }

    if (_showHeatmap) {
      setState(() {
        _showHeatmap = false;
      });
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

        return WeightedLatLng(
          LatLng(lat, lng),
          1.0,
        );
      }).toList();

      setState(() {
        _heatPoints = points;
        _showHeatmap = true;
        _showToolPanel = false;
      });
    } catch (e) {
      print('HEATMAP ERROR: $e');
      _showMsg('Không tải được heatmap. Kiểm tra API /heat.');
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
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
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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

    _showMsg('Backend đã có route export. Bước sau nối tải CSV cho Flutter.');
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

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(40, 90, 40, 260),
        ),
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
        await launchUrl(
          googleMapsApp,
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      await launchUrl(
        googleMapsWeb,
        mode: LaunchMode.externalApplication,
      );
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

    final distanceKm = _distanceInKm(
      _myLocation!,
      LatLng(pharmacy.lat, pharmacy.lng),
    );

    final distanceM = distanceKm * 1000;

    if (distanceM > 700) {
      _showMsg(
        'Bạn chưa tới đúng nhà thuốc. Khoảng cách hiện tại: ${distanceM.toStringAsFixed(1)}m',
      );
      return;
    }

    _showMsg('Bạn đã tới ${pharmacy.name}, được phép chỉnh sửa thông tin');
    _openEditPharmacySheet(pharmacy);
  }

  void _showPharmacyBottomSheet(PharmacyModel pharmacy) {
    final distanceText = _myLocation == null
        ? null
        : _distanceInKm(
      _myLocation!,
      LatLng(pharmacy.lat, pharmacy.lng),
    ).toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        child: const Icon(
                          Icons.medication_rounded,
                          color: Color(0xFFE91E63),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pharmacy.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                  _detailItem(
                    Icons.phone_outlined,
                    'Số điện thoại',
                    pharmacy.phone.isEmpty ? 'Không có' : pharmacy.phone,
                  ),
                  _detailItem(Icons.star_outline, 'Rating', pharmacy.rating?.toString() ?? 'Không có'),
                  _detailItem(
                    Icons.info_outline,
                    'Trạng thái',
                    pharmacy.status.isEmpty ? 'Không có' : pharmacy.status,
                  ),
                  if (pharmacy.productGroups.isNotEmpty)
                    _detailItem(
                      Icons.category_outlined,
                      'Nhóm sản phẩm',
                      pharmacy.productGroups.join(', '),
                    ),
                  if (distanceText != null)
                    _detailItem(Icons.near_me_outlined, 'Khoảng cách', '$distanceText km'),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _openDirections(pharmacy),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.directions),
                      label: const Text(
                        'Dẫn đường đến nhà thuốc',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.fact_check),
                        label: const Text(
                          'Khảo sát thực địa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _openEditPharmacySheet(PharmacyModel pharmacy) {
    final nameController = TextEditingController(text: pharmacy.name);
    final addressController = TextEditingController(text: pharmacy.address);
    final provinceController = TextEditingController(text: pharmacy.province);
    final districtController = TextEditingController(text: pharmacy.district);
    final phoneController = TextEditingController(text: pharmacy.phone);
    final statusController = TextEditingController(text: pharmacy.status);
    final ratingController = TextEditingController(text: pharmacy.rating?.toString() ?? '');
    final imageController = TextEditingController(text: pharmacy.imageUrl);

    final List<String> productOptions = [
      'Thuốc kê đơn',
      'Thuốc không kê đơn',
      'Thực phẩm chức năng',
      'Dược mỹ phẩm',
      'Thiết bị y tế',
      'Vitamin',
      'Sữa / dinh dưỡng',
      'Mẹ và bé',
    ];

    for (final item in pharmacy.productGroups) {
      if (!productOptions.contains(item)) {
        productOptions.add(item);
      }
    }

    List<String> selectedProducts = List<String>.from(pharmacy.productGroups);
    final productController = TextEditingController();
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
              final picked = await _imagePicker.pickImage(
                source: source,
                imageQuality: 75,
                maxWidth: 1600,
              );

              if (picked == null) return;

              setSheetState(() {
                pickedImageFile = File(picked.path);
              });
            }

            Future<void> saveUpdate() async {
              if (saving) return;

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
                  final uploadedUrl = await _pharmacyService.uploadPharmacyImage(
                    pickedImageFile!,
                  );

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
                  name: nameController.text.trim(),
                  address: addressController.text.trim(),
                  province: provinceController.text.trim(),
                  district: districtController.text.trim(),
                  phone: phoneController.text.trim(),
                  status: statusController.text.trim(),
                  rating: double.tryParse(ratingController.text.trim()),
                  imageUrl: finalImageUrl,
                  productGroups: selectedProducts,
                );

                if (!mounted) return;

                setSheetState(() => saving = false);

                if (updated != null) {
                  Navigator.pop(context);
                  _showMsg('Cập nhật nhà thuốc thành công');
                  await _loadPharmaciesByViewport();
                } else {
                  _showMsg('Cập nhật thất bại');
                }
              } catch (e) {
                setSheetState(() => saving = false);
                _showMsg('Lỗi cập nhật: $e');
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
                      'Cập nhật thông tin nhà thuốc',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _editField('Tên nhà thuốc', nameController),
                    _editField('Địa chỉ', addressController, maxLines: 2),
                    _editField('Tỉnh / Thành phố', provinceController),
                    _editField('Quận / Huyện', districtController),
                    _editField('Số điện thoại', phoneController),
                    _editField('Trạng thái', statusController),
                    _editField(
                      'Rating',
                      ratingController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _editField('URL ảnh nhà thuốc', imageController, maxLines: 2),
                    const SizedBox(height: 8),
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
                            onPressed: () => pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Chụp ảnh'),
                          ),
                        ),
                      ],
                    ),
                    if (pickedImageFile != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          pickedImageFile!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Nhóm sản phẩm nhà thuốc bán',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: productController,
                            decoration: InputDecoration(
                              hintText: 'Thêm nhóm sản phẩm mới',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final text = productController.text.trim();
                            if (text.isEmpty) return;

                            setSheetState(() {
                              if (!productOptions.contains(text)) {
                                productOptions.add(text);
                              }

                              if (!selectedProducts.contains(text)) {
                                selectedProducts.add(text);
                              }

                              productController.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E63),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Thêm'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
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
                          saving ? 'Đang lưu...' : 'Lưu cập nhật',
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
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
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
                Text(
                  title,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bộ lọc dữ liệu',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tỉnh / Thành phố',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: '-- Tất cả --',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('-- Tất cả --'),
                      ),
                      ..._provinces.map(
                            (province) => DropdownMenuItem<String>(
                          value: province,
                          child: Text(province),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedProvince = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rating tối thiểu',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ratingController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'VD: 4.0',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Áp dụng bộ lọc',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                          _pharmacies = _allPharmacies;
                          _searchResults = [];
                          _showHeatmap = false;
                          _showSearchResults = false;
                        });

                        Navigator.pop(context);
                        _mapController.move(_defaultCenter, 5.6);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  List<Marker> _buildMarkers() {
    final validPharmacies = _pharmacies.where((p) {
      return p.lat != 0 && p.lng != 0;
    }).toList();

    final markers = validPharmacies.map((pharmacy) {
      return Marker(
        point: LatLng(pharmacy.lat, pharmacy.lng),
        width: pharmacy.isSurveyed ? 46 : 36,
        height: pharmacy.isSurveyed ? 46 : 36,
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

    if (_myLocation != null) {
      markers.insert(
        0,
        Marker(
          point: _myLocation!,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
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
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onPositionChanged: (position, hasGesture) {
          if (!hasGesture) return;

          _moveDebounce?.cancel();
          _moveDebounce = Timer(
            const Duration(milliseconds: 1000),
                () {
              _loadPharmaciesByViewport();
            },
          );
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.pharmacy_mobile',
          tileDisplay: const TileDisplay.fadeIn(),
          panBuffer: 0,
          keepBuffer: 1,
          maxNativeZoom: 19,
        ),
        if (_showHeatmap && _heatPoints.isNotEmpty)
          HeatMapLayer(
            heatMapDataSource: InMemoryHeatMapDataSource(data: _heatPoints),
            heatMapOptions: HeatMapOptions(
              minOpacity: 0.3,
              radius: 18,
            ),
          ),
        RepaintBoundary(
          child: MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 120,
              disableClusteringAtZoom: 17,
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
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Bản đồ nhà thuốc',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
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
            IconButton(
              onPressed: _runSearch,
              icon: const Icon(Icons.search, size: 21),
              splashRadius: 20,
            ),
            IconButton(
              onPressed: _closeSearchBar,
              icon: const Icon(Icons.close, size: 21),
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRightControls() {
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

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: _roleColor, size: 15),
          const SizedBox(width: 5),
          Text(
            _roleLabel,
            style: TextStyle(
              color: _roleColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = min(screenWidth * 0.68, 250.0);

    return Positioned(
      left: 12,
      top: MediaQuery.of(context).padding.top + 82,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        offset: _showToolPanel ? Offset.zero : const Offset(-1.05, 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _showToolPanel ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_showToolPanel,
            child: Container(
              width: panelWidth,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.58,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Công cụ hiển thị',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quyền hiện tại: $_roleLabel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _roleColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_canViewAdvancedFeatures) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _showToolPanel = false);
                            _showProvinceStatsDialog();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3E8BE8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.local_hospital, size: 18),
                          label: const Text(
                            'Xem thông tin khu vực',
                            style: TextStyle(fontSize: 14),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: Icon(
                            _showHeatmap ? Icons.layers_clear : Icons.local_fire_department,
                            size: 16,
                          ),
                          label: Text(
                            _showHeatmap ? 'Tắt heatmap' : 'Xem heatmap',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.my_location, size: 18),
                              label: const Text(
                                'Lấy vị trí',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _radiusController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '5',
                              suffixText: 'km',
                              suffixStyle: const TextStyle(fontSize: 12),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: _filterNearby,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(Icons.near_me, size: 18),
                        label: const Text('Lọc gần tôi', style: TextStyle(fontSize: 14)),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Export CSV', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                    const SizedBox(height: 8),
                    Text(
                      'Tổng DB: ${_totalPharmacyCount == 0 ? 25000 : _totalPharmacyCount}\n'
                          'Marker đang tải: ${_pharmacies.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.4,
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.36,
          minHeight: 120,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(99),
              ),
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
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Không tìm thấy nhà thuốc phù hợp'),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final p = _searchResults[index];

                  final distanceText = _myLocation == null
                      ? null
                      : _distanceInKm(
                    _myLocation!,
                    LatLng(p.lat, p.lng),
                  ).toStringAsFixed(2);

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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
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

  void _showMsg(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
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
          if (_showSearchBar) _buildSearchBox(),
          if (!_showSearchBar) _buildTopRightControls(),
          _buildToolPanel(),
          if (_showSearchResults) _buildSearchResultPanel(),
        ],
      ),
    );
  }
}
