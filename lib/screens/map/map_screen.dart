import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
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

  List<String> _provinces = [];
  List<PharmacyModel> _allPharmacies = [];
  List<PharmacyModel> _pharmacies = [];
  List<PharmacyModel> _searchResults = [];
  List<Map<String, dynamic>> _provinceStats = [];
  List<WeightedLatLng> _heatPoints = [];

  String? _selectedProvince;
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _radiusController =
  TextEditingController(text: '5');

  bool _isLoading = true;
  bool _showSearchBar = false;
  bool _showSearchResults = true;
  bool _showHeatmap = false;
  bool _sortNearest = true;
  bool _showToolPanel = false;

  LatLng? _myLocation;

  final LatLng _defaultCenter = const LatLng(16.0544, 108.2022);

  bool get _canViewAdvancedFeatures =>
      widget.role == 'company' || widget.role == 'admin';

  bool get _canExport => widget.role == 'company' || widget.role == 'admin';

  bool get _isAdmin => widget.role == 'admin';

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

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final provinces = await _pharmacyService.getProvinces();

    const bbox = '102.0,8.0,110.5,24.5';

    final pharmacies = await _pharmacyService.getPharmaciesGeoJson(
      bbox: bbox,
    );

    if (!mounted) return;

    setState(() {
      _provinces = provinces;
      _allPharmacies = pharmacies;
      _pharmacies = pharmacies;
      _searchResults = pharmacies;
      _showSearchResults = true;
      _isLoading = false;
    });

    _fitMapToMarkers(_pharmacies);
  }

  Future<void> _applyFilter() async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    final ratingMin = double.tryParse(_ratingController.text.trim());

    const bbox = '102.0,8.0,110.5,24.5';

    final pharmacies = await _pharmacyService.getPharmaciesGeoJson(
      bbox: bbox,
      province: _selectedProvince,
      ratingMin: ratingMin,
    );

    if (!mounted) return;

    setState(() {
      _allPharmacies = pharmacies;
      _pharmacies = pharmacies;
      _searchResults = pharmacies;
      _showSearchResults = true;
      _showHeatmap = false;
      _isLoading = false;
    });

    _fitMapToMarkers(_pharmacies);
  }

  void _searchPharmacy(String keyword) {
    final text = keyword.trim().toLowerCase();

    if (text.isEmpty) {
      setState(() {
        _searchResults = _pharmacies;
        _showSearchResults = true;
      });
      return;
    }

    final results = _pharmacies.where((p) {
      return p.name.toLowerCase().contains(text) ||
          p.address.toLowerCase().contains(text) ||
          p.province.toLowerCase().contains(text) ||
          p.district.toLowerCase().contains(text);
    }).toList();

    setState(() {
      _searchResults = results;
      _showSearchResults = true;
    });
  }

  Future<void> _runSearch() async {
    _searchPharmacy(_searchController.text);
  }

  void _closeSearchBar() {
    setState(() {
      _showSearchBar = false;
      _searchController.clear();
      _searchResults = _pharmacies;
      _showSearchResults = true;
    });
  }

  Future<void> _getMyLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMsg('Bạn chưa bật GPS / dịch vụ vị trí');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMsg('Ứng dụng chưa được cấp quyền vị trí');
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

    final filtered = _allPharmacies.where((p) {
      final d = _distanceInKm(_myLocation!, LatLng(p.lat, p.lng));
      return d <= radiusKm;
    }).toList();

    if (_sortNearest) {
      filtered.sort((a, b) {
        final da = _distanceInKm(_myLocation!, LatLng(a.lat, a.lng));
        final db = _distanceInKm(_myLocation!, LatLng(b.lat, b.lng));
        return da.compareTo(db);
      });
    }

    setState(() {
      _pharmacies = filtered;
      _searchResults = filtered;
      _showSearchResults = true;
      _showHeatmap = false;
      _showToolPanel = false;
    });

    _fitMapToMarkers(_pharmacies);

    if (filtered.isEmpty) {
      _showMsg('Không có nhà thuốc nào trong bán kính $radiusKm km');
    } else {
      _showMsg('Đã lọc ${filtered.length} nhà thuốc trong bán kính $radiusKm km');
    }
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

    final ratingMin = double.tryParse(_ratingController.text.trim());
    final heatData = await _pharmacyService.getHeatmap(
      province: _selectedProvince,
      ratingMin: ratingMin,
    );

    final points = heatData.map((e) {
      final lat = (e['lat'] as num).toDouble();
      final lon = (e['lon'] as num).toDouble();
      final weight = e['w'] == null ? 1.0 : (e['w'] as num).toDouble();

      return WeightedLatLng(
        LatLng(lat, lon),
        weight,
      );
    }).toList();

    setState(() {
      _heatPoints = points;
      _showHeatmap = true;
      _showToolPanel = false;
    });
  }

  Future<void> _showProvinceStatsDialog() async {
    if (!_canViewAdvancedFeatures) {
      _showMsg('Chỉ company hoặc admin mới xem được thống kê');
      return;
    }

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
  }

  Future<void> _exportCsv() async {
    if (!_canExport) {
      _showMsg('Chỉ company hoặc admin mới được export CSV');
      return;
    }

    _showMsg(
      'Backend đã sẵn sàng route export. Bước sau mình sẽ nối nút tải CSV cho Flutter.',
    );
  }

  void _fitMapToMarkers(List<PharmacyModel> list) {
    if (list.isEmpty) {
      _mapController.move(_defaultCenter, 6);
      return;
    }

    if (list.length == 1) {
      final p = list.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(p.lat, p.lng), 16);
      });
      return;
    }

    double minLat = list.first.lat;
    double maxLat = list.first.lat;
    double minLng = list.first.lng;
    double maxLng = list.first.lng;

    for (final p in list) {
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
          padding: const EdgeInsets.all(36),
        ),
      );
    });
  }

  void _moveToPharmacy(PharmacyModel p) {
    _mapController.move(LatLng(p.lat, p.lng), 17);
  }

  Future<void> _openDirections(PharmacyModel pharmacy) async {
    final lat = pharmacy.lat;
    final lng = pharmacy.lng;

    if (lat == 0 || lng == 0) {
      _showMsg('Nhà thuốc chưa có tọa độ hợp lệ');
      return;
    }

    final googleMapsApp = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d',
    );

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

  void _showPharmacyBottomSheet(PharmacyModel pharmacy) {
    final distanceText = _myLocation == null
        ? null
        : _distanceInKm(_myLocation!, LatLng(pharmacy.lat, pharmacy.lng))
        .toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _detailItem(Icons.location_on_outlined, 'Địa chỉ', pharmacy.address),
                _detailItem(Icons.map_outlined, 'Tỉnh / Thành', pharmacy.province),
                _detailItem(
                  Icons.account_balance_outlined,
                  'Quận / Huyện',
                  pharmacy.district,
                ),
                _detailItem(
                  Icons.phone_outlined,
                  'Số điện thoại',
                  pharmacy.phone.isEmpty ? 'Không có' : pharmacy.phone,
                ),
                _detailItem(
                  Icons.star_outline,
                  'Rating',
                  pharmacy.rating?.toString() ?? 'Không có',
                ),
                _detailItem(
                  Icons.info_outline,
                  'Trạng thái',
                  pharmacy.status.isEmpty ? 'Không có' : pharmacy.status,
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
              ],
            ),
          ),
        );
      },
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
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
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
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                          _searchResults = _allPharmacies;
                          _showHeatmap = false;
                          _showSearchResults = true;
                        });
                        Navigator.pop(context);
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
    final markers = _pharmacies.map((pharmacy) {
      return Marker(
        point: LatLng(pharmacy.lat, pharmacy.lng),
        width: 34,
        height: 20,
        child: GestureDetector(
          onTap: () {
            _moveToPharmacy(pharmacy);
            _showPharmacyBottomSheet(pharmacy);
          },
          child: _buildCapsuleMarker(),
        ),
      );
    }).toList();

    if (_myLocation != null) {
      markers.add(
        Marker(
          point: _myLocation!,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 11,
                height: 11,
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

  Widget _buildCapsuleMarker() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFFF7AAE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.medication_rounded,
          color: Colors.white,
          size: 12,
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 6,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.pharmacy_mobile',
          panBuffer: 1,
        ),
        if (_showHeatmap && _heatPoints.isNotEmpty)
          HeatMapLayer(
            heatMapDataSource: InMemoryHeatMapDataSource(data: _heatPoints),
            heatMapOptions: HeatMapOptions(
              minOpacity: 0.3,
              radius: 18,
            ),
          ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 26,
            size: const Size(36, 36),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            maxZoom: 16,
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
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            },
            onClusterTap: (cluster) {
              _mapController.move(
                cluster.bounds.center,
                _mapController.camera.zoom + 1.5,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Positioned(
      top: 14,
      left: 14,
      right: 76,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
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
                onChanged: _searchPharmacy,
                onSubmitted: (_) => _runSearch(),
                decoration: const InputDecoration(
                  hintText: 'Tìm nhà thuốc...',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              onPressed: _runSearch,
              icon: const Icon(Icons.search, size: 20),
              splashRadius: 20,
            ),
            IconButton(
              onPressed: _closeSearchBar,
              icon: const Icon(Icons.close, size: 20),
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRightControls() {
    return Positioned(
      top: 14,
      right: 12,
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
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 21,
            color: const Color(0xFF222222),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
          Icon(Icons.verified_user, color: _roleColor, size: 16),
          const SizedBox(width: 6),
          Text(
            _roleLabel,
            style: TextStyle(
              color: _roleColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = min(screenWidth * 0.76, 290.0);

    return Positioned(
      left: 12,
      top: 88,
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
              constraints: const BoxConstraints(maxHeight: 470),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _pharmacies = _allPharmacies;
                            _searchResults = _allPharmacies;
                            _showSearchResults = true;
                            _showHeatmap = false;
                            _showToolPanel = false;
                          });
                          _fitMapToMarkers(_pharmacies);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF59B15A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(Icons.medication_rounded, size: 18),
                        label: const Text(
                          'Tất cả nhà thuốc',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                            _showHeatmap
                                ? Icons.layers_clear
                                : Icons.local_fire_department,
                            size: 18,
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
                                padding:
                                const EdgeInsets.symmetric(horizontal: 8),
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
                          width: 72,
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
                              contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
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
                        label: const Text(
                          'Lọc gần tôi',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.9,
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
                          child: Text(
                            'Sắp xếp gần nhất',
                            style: TextStyle(fontSize: 13),
                          ),
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
                          label: const Text(
                            'Export CSV',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                    if (_isAdmin) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Admin có thể mở rộng thêm màn quản lý users và pharmacies ở bước tiếp theo.',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
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
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.black54,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _myLocation == null
                                  ? 'Chưa lấy được vị trí'
                                  : 'Đã lấy vị trí hiện tại',
                              style: TextStyle(
                                color:
                                _myLocation == null ? Colors.red : Colors.green,
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
                      'Kết quả: ${_pharmacies.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 13,
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
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'Kết quả tìm kiếm'
                          : 'Kết quả (${_searchResults.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showSearchResults = false;
                      });
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFFE91E63),
                    ),
                    label: const Text(
                      'Đóng',
                      style: TextStyle(
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Không tìm thấy nhà thuốc phù hợp'),
                ),
              )
                  : ListView.builder(
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medication_rounded,
                        color: Color(0xFFE91E63),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      distanceText == null
                          ? p.address
                          : '${p.address}\nCách ${distanceText} km',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
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

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _ratingController.dispose();
    _searchController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Bản đồ nhà thuốc - $_roleLabel',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
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
                child: Container(
                  color: Colors.black.withOpacity(0.08),
                ),
              ),
            ),
          if (_showSearchBar) _buildSearchBox(),
          if (!_showSearchBar) _buildTopRightControls(),
          _buildToolPanel(),
          if (_showSearchResults) _buildSearchResultPanel(),
        ],
      ),
    );
  }
}