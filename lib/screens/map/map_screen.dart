import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../../models/pharmacy_model.dart';
import '../../services/pharmacy_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  final MapController _mapController = MapController();

  List<String> _provinces = [];
  List<PharmacyModel> _pharmacies = [];

  String? _selectedProvince;
  final TextEditingController _ratingController = TextEditingController();

  bool _isLoading = true;

  final LatLng _defaultCenter = const LatLng(16.0544, 108.2022);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    final provinces = await _pharmacyService.getProvinces();
    final pharmacies = await _pharmacyService.getPharmacies(limit: 1000);

    if (!mounted) return;

    setState(() {
      _provinces = provinces;
      _pharmacies = pharmacies;
      _isLoading = false;
    });

    _fitMapToMarkers();
  }

  Future<void> _applyFilter() async {
    Navigator.pop(context);

    setState(() {
      _isLoading = true;
    });

    final ratingMin = double.tryParse(_ratingController.text.trim());

    final pharmacies = await _pharmacyService.getPharmacies(
      province: _selectedProvince,
      ratingMin: ratingMin,
      limit: 2000,
    );

    if (!mounted) return;

    setState(() {
      _pharmacies = pharmacies;
      _isLoading = false;
    });

    _fitMapToMarkers();
  }

  void _fitMapToMarkers() {
    if (_pharmacies.isEmpty) {
      _mapController.move(_defaultCenter, 6);
      return;
    }

    if (_pharmacies.length == 1) {
      final p = _pharmacies.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(p.lat, p.lng), 15);
      });
      return;
    }

    double minLat = _pharmacies.first.lat;
    double maxLat = _pharmacies.first.lat;
    double minLng = _pharmacies.first.lng;
    double maxLng = _pharmacies.first.lng;

    for (final p in _pharmacies) {
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
          padding: const EdgeInsets.all(40),
        ),
      );
    });
  }

  void _showPharmacyBottomSheet(PharmacyModel pharmacy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Wrap(
            children: [
              Text(
                pharmacy.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 12),
              Text('Địa chỉ: ${pharmacy.address}'),
              const SizedBox(height: 8),
              Text('Tỉnh/Thành: ${pharmacy.province}'),
              const SizedBox(height: 8),
              Text('Quận/Huyện: ${pharmacy.district}'),
              const SizedBox(height: 8),
              Text(
                'Số điện thoại: ${pharmacy.phone.isEmpty ? "Không có" : pharmacy.phone}',
              ),
              const SizedBox(height: 8),
              Text(
                'Trạng thái: ${pharmacy.status.isEmpty ? "Không có" : pharmacy.status}',
              ),
              const SizedBox(height: 8),
              Text('Rating: ${pharmacy.rating?.toString() ?? "Không có"}'),
            ],
          ),
        );
      },
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tỉnh / Thành phố',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: '-- Tất cả --',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ratingController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'VD: 4.0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Áp dụng bộ lọc',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedProvince = null;
                          _ratingController.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    return _pharmacies.map((pharmacy) {
      return Marker(
        point: LatLng(pharmacy.lat, pharmacy.lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showPharmacyBottomSheet(pharmacy),
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 34,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTopOverlay() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Text(
                'Số nhà thuốc: ${_pharmacies.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.pink,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _openFilterSheet,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Bộ lọc',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(44, 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(50),
            maxZoom: 15,
            markers: _buildMarkers(),
            builder: (context, markers) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    markers.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
            onClusterTap: (cluster) {
              _mapController.move(
                cluster.bounds.center,
                _mapController.camera.zoom + 2,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPharmacyList() {
    if (_pharmacies.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    return ListView.builder(
      itemCount: _pharmacies.length,
      itemBuilder: (context, index) {
        final p = _pharmacies[index];

        return ListTile(
          leading: const Icon(Icons.local_pharmacy, color: Colors.pink),
          title: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            p.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            p.rating?.toString() ?? '-',
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () {
            _mapController.move(
              LatLng(p.lat, p.lng),
              16,
            );
            _showPharmacyBottomSheet(p);
          },
        );
      },
    );
  }

  Widget _buildDraggableList() {
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.10,
      maxChildSize: 0.60,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black26,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                'Danh sách nhà thuốc',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _pharmacies.isEmpty
                    ? const Center(child: Text('Không có dữ liệu'))
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: _pharmacies.length,
                  itemBuilder: (context, index) {
                    final p = _pharmacies[index];

                    return ListTile(
                      leading: const Icon(
                        Icons.local_pharmacy,
                        color: Colors.pink,
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        p.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        p.rating?.toString() ?? '-',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        _mapController.move(
                          LatLng(p.lat, p.lng),
                          16,
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

  @override
  void dispose() {
    _ratingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ nhà thuốc'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          _buildTopOverlay(),
          _buildDraggableList(),
        ],
      ),
    );
  }
}