import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'api_service.dart';

class SurveyAreaService {
  Map<String, dynamic> _polygonToJson(List<LatLng> points) {
    final coords = points
        .map(
          (p) => [
        p.longitude,
        p.latitude,
      ],
    )
        .toList();

    if (coords.isNotEmpty) {
      final first = coords.first;
      final last = coords.last;

      if (first[0] != last[0] || first[1] != last[1]) {
        coords.add(first);
      }
    }

    return {
      'type': 'Polygon',
      'coordinates': [
        coords,
      ],
    };
  }

  List<LatLng> parsePolygon(dynamic polygon) {
    try {
      dynamic data = polygon;

      if (data is String) {
        data = data.trim();
      }

      if (data is Map) {
        final coordinates = data['coordinates'];

        if (coordinates is List &&
            coordinates.isNotEmpty &&
            coordinates.first is List) {
          final firstRing = coordinates.first as List;

          return firstRing
              .whereType<List>()
              .where((p) => p.length >= 2)
              .map(
                (p) => LatLng(
              double.tryParse(p[1].toString()) ?? 0,
              double.tryParse(p[0].toString()) ?? 0,
            ),
          )
              .where((p) => p.latitude != 0 && p.longitude != 0)
              .toList();
        }
      }

      return [];
    } catch (e) {
      print('PARSE POLYGON ERROR: $e');
      return [];
    }
  }

  Future<bool> createSurveyArea({
    required String name,
    required List<LatLng> points,
  }) async {
    try {
      if (points.length < 3) {
        return false;
      }

      final res = await ApiService.dio.post(
        '/survey-areas',
        data: {
          'name': name,
          'polygon': _polygonToJson(points),
        },
      );

      return res.statusCode == 200 || res.statusCode == 201;
    } on DioException catch (e) {
      print('CREATE SURVEY AREA STATUS: ${e.response?.statusCode}');
      print('CREATE SURVEY AREA DATA: ${e.response?.data}');
      return false;
    } catch (e) {
      print('CREATE SURVEY AREA ERROR: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMySurveyAreas() async {
    try {
      final res = await ApiService.dio.get('/survey-areas/my');
      final data = res.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('GET MY SURVEY AREAS ERROR: $e');
      return [];
    }
  }

  Future<bool> updateSurveyArea({
    required int id,
    String? name,
    List<LatLng>? points,
  }) async {
    try {
      final res = await ApiService.dio.put(
        '/survey-areas/$id',
        data: {
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (points != null && points.length >= 3)
            'polygon': _polygonToJson(points),
        },
      );

      return res.statusCode == 200;
    } catch (e) {
      print('UPDATE SURVEY AREA ERROR: $e');
      return false;
    }
  }

  Future<bool> deleteSurveyArea(int id) async {
    try {
      final res = await ApiService.dio.delete('/survey-areas/$id');
      return res.statusCode == 200;
    } catch (e) {
      print('DELETE SURVEY AREA ERROR: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> adminGetSurveyUsers() async {
    try {
      final res = await ApiService.dio.get('/survey-areas/admin/users');
      final data = res.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('ADMIN GET SURVEY USERS ERROR: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> adminGetSurveyAreasByUser(
      int userId,
      ) async {
    try {
      final res = await ApiService.dio.get(
        '/survey-areas/admin/user/$userId',
      );

      final data = res.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      return [];
    } catch (e) {
      print('ADMIN GET SURVEY AREAS BY USER ERROR: $e');
      return [];
    }
  }

  Future<bool> adminDeleteSurveyArea(int id) async {
    try {
      final res = await ApiService.dio.delete('/survey-areas/admin/$id');
      return res.statusCode == 200;
    } catch (e) {
      print('ADMIN DELETE SURVEY AREA ERROR: $e');
      return false;
    }
  }
}