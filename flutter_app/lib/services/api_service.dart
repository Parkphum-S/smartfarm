import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static Future<List<dynamic>> getZones() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/zones'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }
      throw Exception('Failed to load zones');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  static Future<List<dynamic>> getSensors() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/sensors'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }
      throw Exception('Failed to load sensors');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }
    static Future<bool> sendActuatorCommand({

    required String actuatorId,

    required String action, // 'on' หรือ 'off'

    required String zoneId,

  }) async {

    try {

      final response = await http.post(

        Uri.parse('${AppConfig.apiBaseUrl}/device/$actuatorId/command'),

        headers: {'Content-Type': 'application/json'},

        body: json.encode({

          'action': action,

          'zone_id': zoneId,

          'source': 'mobile_app',

        }),

      );

      

      // ถ้าระบบตอบรับสำเร็จ (200 หรือ 201)

      return response.statusCode == 200 || response.statusCode == 201;

    } catch (e) {

      debugPrint('Command Error: $e');

      return false;

    }

  }
    static Future<bool> createZone({required String code, required String name, required String zoneType}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/zones'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'farm_id': 1,
          'code': code,
          'name': name,
          'zone_type': zoneType,
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Create Zone Error: $e');
      return false;
    }
  }

  static Future<bool> deleteZone(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/zones/$id'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Delete Zone Error: $e');
      return false;
    }
  }
    static Future<List<dynamic>> getEsp32Devices() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/esp32-devices'));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }
      throw Exception('Failed to load ESP32 devices');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  static Future<bool> registerEsp32Device({required String code, required String name, int? zoneId}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/esp32-devices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'farm_id': 1,
          'zone_id': zoneId,
          'code': code,
          'name': name,
          'mqtt_client_id': code,
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Register Device Error: $e');
      return false;
    }
  }
  // SOIL TEST
  // ============================================================

  static Future<bool> createSoilTest({
    required int zoneId,
    required double ph,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    String? note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/soil-tests'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'zone_id': zoneId,
          'ph': ph,
          'nitrogen': nitrogen,
          'phosphorus': phosphorus,
          'potassium': potassium,
          'note': note,
        }),
      );

      if (response.statusCode == 201 ||
          response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;

        return data['status'] == 'success';
      }

      debugPrint(
        'Soil Test Error: ${response.statusCode} '
        '${response.body}',
      );

      return false;
    } catch (e) {
      debugPrint('Soil Test Error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getSoilTestHistory(
    int zoneId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.apiBaseUrl}/soil-tests?zone_id=$zoneId',
        ),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load soil test history: '
          '${response.statusCode}',
        );
      }

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'success') {
        throw Exception(
          data['message']?.toString() ??
              'Failed to load soil test history',
        );
      }

      return (data['data'] as List<dynamic>?) ?? [];
    } catch (e) {
      debugPrint('Soil Test History Error: $e');
      rethrow;
    }
  }

}