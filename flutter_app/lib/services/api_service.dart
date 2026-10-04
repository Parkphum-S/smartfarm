import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiService {
  // ============================================================
  // DEVICE BOARD TYPES
  // ============================================================

  static Future<List<dynamic>> getDeviceBoardTypes() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/device-board-types'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }

      throw Exception('Failed to load device board types');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // ============================================================
  // ZONES
  // ============================================================

  static Future<List<dynamic>> getZones() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/zones'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }

      throw Exception('Failed to load zones');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  static Future<bool> createZone({
    required String code,
    required String name,
    required String zoneType,
  }) async {
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

  static Future<bool> updateZone({
    required int id,
    required String code,
    required String name,
    required String zoneType,
    String? description,
    required String status,
    required int sortOrder,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/zones/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'name': name,
          'zone_type': zoneType,
          'description': description,
          'status': status,
          'sort_order': sortOrder,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update Zone Error: $e');
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

  // ============================================================
  // SENSORS
  // ============================================================

  static Future<List<dynamic>> getSensors() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/sensors'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }

      throw Exception('Failed to load sensors');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  static Future<List<dynamic>> getSensorTypes() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/sensor-types'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }

      throw Exception('Failed to load sensor types');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  static Future<List<dynamic>> getSensorInterfaces() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/sensor-interfaces'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }

      throw Exception('Failed to load sensor interfaces');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  static Future<bool> registerSensor({
    required int zoneId,
    required int esp32DeviceId,
    required int sensorTypeId,
    required String sensorCode,
    required String name,
    String? hardwareIdentifier,
    String interfaceType = 'gpio',
    String? connectionConfigJson,
    String? calibrationConfigJson,
    String? unit,
    double? validMin,
    double? validMax,
    int samplingIntervalSeconds = 300,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/sensors'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'farm_id': 1,
          'zone_id': zoneId,
          'esp32_device_id': esp32DeviceId,
          'sensor_type_id': sensorTypeId,
          'sensor_code': sensorCode,
          'name': name,
          'hardware_identifier': hardwareIdentifier,
          'interface_type': interfaceType,
          'connection_config_json': connectionConfigJson,
          'calibration_config_json': calibrationConfigJson,
          'unit': unit,
          'valid_min': validMin,
          'valid_max': validMax,
          'sampling_interval_seconds': samplingIntervalSeconds,
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Register Sensor Error: $e');
      return false;
    }
  }

  static Future<bool> updateSensor({
    required int id,
    required int zoneId,
    required int esp32DeviceId,
    required int sensorTypeId,
    required String sensorCode,
    required String name,
    String? hardwareIdentifier,
    String interfaceType = 'gpio',
    String? connectionConfigJson,
    String? calibrationConfigJson,
    String? unit,
    double? validMin,
    double? validMax,
    int samplingIntervalSeconds = 300,
    String status = 'active',
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/sensors/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'farm_id': 1,
          'zone_id': zoneId,
          'esp32_device_id': esp32DeviceId,
          'sensor_type_id': sensorTypeId,
          'sensor_code': sensorCode,
          'name': name,
          'hardware_identifier': hardwareIdentifier,
          'interface_type': interfaceType,
          'connection_config_json': connectionConfigJson,
          'calibration_config_json': calibrationConfigJson,
          'unit': unit,
          'valid_min': validMin,
          'valid_max': validMax,
          'sampling_interval_seconds': samplingIntervalSeconds,
          'status': status,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update Sensor Error: $e');
      return false;
    }
  }

  static Future<bool> deleteEsp32Device(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/esp32-devices/$id'),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Delete Device Error: $e');
      return false;
    }
  }

  static Future<bool> updateEsp32Device({
    required int id,
    required int? zoneId,
    required String code,
    required String name,
    String? boardType,
    String? deviceRole,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/esp32-devices/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'farm_id': 1,
          'zone_id': zoneId,
          'code': code,
          'name': name,
          'board_type': boardType,
          'device_role': deviceRole,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Update Device Error: $e');
      return false;
    }
  }

  static Future<bool> deleteSensor(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/sensors/$id'),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Delete Sensor Error: $e');
      return false;
    }
  }

  // ============================================================
  // ACTUATORS
  // ============================================================

  /// อ่าน Actuator พร้อมสถานะจริงจาก Backend
  ///
  /// API:
  /// GET /api/v1/actuators
  ///
  /// ข้อมูลสำคัญ:
  /// - actual_state
  /// - desired_state
  /// - device_health
  /// - error_code
  /// - error_message
  /// - state_updated_at
  static Future<List<dynamic>> getActuators() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/actuators'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }

      throw Exception('Failed to load actuators');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  /// ส่งคำสั่งควบคุม Actuator
  ///
  /// หมายเหตุ:
  /// HTTP success หมายถึง Backend รับคำสั่งและ publish MQTT สำเร็จ
  /// ไม่ได้หมายความว่า Relay อยู่ในสถานะนั้นแล้ว
  static Future<Map<String, dynamic>> sendActuatorCommandDetailed({
    required String actuatorId,
    required String action,
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

      Map<String, dynamic> data = {};

      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        data = {};
      }

      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'statusCode': response.statusCode,
        'message': data['message']?.toString(),
        'data': data,
      };
    } catch (e) {
      debugPrint('Command Error: $e');

      return {
        'success': false,
        'statusCode': 0,
        'message': 'Network error',
        'data': <String, dynamic>{},
      };
    }
  }

  /// ส่งคำสั่งควบคุม Actuator แบบง่าย
  ///
  /// ใช้สำหรับ UI ที่ต้องการเพียงผลลัพธ์ว่า
  /// Backend รับคำสั่งสำเร็จหรือไม่
  ///
  /// สถานะจริงของ Actuator ต้องอ่านจาก actual_state
  /// ผ่าน getActuators()
  static Future<bool> sendActuatorCommand({
    required String actuatorId,
    required String action,
    required String zoneId,
  }) async {
    final Map<String, dynamic> result = await sendActuatorCommandDetailed(
      actuatorId: actuatorId,
      action: action,
      zoneId: zoneId,
    );

    return result['success'] == true;
  }

  static Future<List<dynamic>> getActuatorHistory(String actuatorId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/actuators/$actuatorId/history'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load actuator history: ${response.statusCode}',
      );
    }

    final Map<String, dynamic> data =
        json.decode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'success') {
      throw Exception(
        data['message']?.toString() ?? 'Failed to load actuator history',
      );
    }

    return (data['data'] as List<dynamic>?) ?? [];
  }
  // ============================================================
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
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'zone_id': zoneId,
          'ph': ph,
          'nitrogen': nitrogen,
          'phosphorus': phosphorus,
          'potassium': potassium,
          'note': note,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
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

  static Future<List<dynamic>> getSoilTestHistory(int zoneId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/soil-tests?zone_id=$zoneId'),
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
          data['message']?.toString() ?? 'Failed to load soil test history',
        );
      }

      return (data['data'] as List<dynamic>?) ?? [];
    } catch (e) {
      debugPrint('Soil Test History Error: $e');
      rethrow;
    }
  }
  // ============================================================
  // ESP32 DEVICES
  // ============================================================

  static Future<List<dynamic>> getEsp32Devices() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/esp32-devices'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      }

      throw Exception('Failed to load ESP32 devices');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  static Future<bool> registerEsp32Device({
    required String code,
    required String name,
    int? zoneId,
    String? boardType,
    String? deviceRole,
  }) async {
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
          'board_type': boardType,
          'device_role': deviceRole,
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Register Device Error: $e');
      return false;
    }
  }
}
