import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthService {
  AuthService._();

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  // ============================================================
  // SESSION GETTERS
  // ============================================================

  /// Token ปัจจุบัน
  static String? get token => _token;

  /// User ปัจจุบัน
  static Map<String, dynamic>? get currentUser => _currentUser;

  /// ตรวจว่ามี Login อยู่หรือไม่
  static bool get isLoggedIn =>
      _token != null && _token!.isNotEmpty;

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/auth/login.php',
    );

    debugPrint('========================================');
    debugPrint('LOGIN: starting');
    debugPrint('LOGIN: URL=$uri');
    debugPrint('LOGIN: username=${username.trim()}');
    debugPrint('LOGIN: sending request');
    debugPrint('========================================');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      );

      debugPrint('LOGIN: response received');
      debugPrint(
        'LOGIN: status=${response.statusCode}',
      );

      // ไม่แสดง response.body
      // เพราะ response มี authentication token
      debugPrint(
        'LOGIN: response length=${response.body.length}',
      );

      final responseData = _decodeResponse(response);

      debugPrint(
        'LOGIN: success=${responseData['success']}',
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['success'] == true) {
        final data = Map<String, dynamic>.from(
          responseData['data'] ?? {},
        );

        final token = data['token'];

        if (token is! String || token.isEmpty) {
          debugPrint(
            'LOGIN: ERROR - token missing',
          );

          throw Exception(
            'Login สำเร็จแต่ Server ไม่ส่ง authentication token',
          );
        }

        // เก็บ Token ไว้ใน memory
        _token = token;

        debugPrint(
          'LOGIN: token received successfully',
        );

        final user = data['user'];

        if (user is Map) {
          _currentUser =
              Map<String, dynamic>.from(user);

          debugPrint(
            'LOGIN: user=${_currentUser?['username']}',
          );

          debugPrint(
            'LOGIN: role=${_currentUser?['role']}',
          );
        } else {
          _currentUser = null;

          debugPrint(
            'LOGIN: warning - user data missing',
          );
        }

        debugPrint(
          'LOGIN: authentication successful',
        );

        debugPrint('========================================');

        return data;
      }

      debugPrint(
        'LOGIN: authentication failed',
      );

      final message =
          responseData['message']?.toString() ??
              'เข้าสู่ระบบไม่สำเร็จ';

      debugPrint(
        'LOGIN: message=$message',
      );

      debugPrint('========================================');

      throw Exception(message);
    } catch (e) {
      debugPrint(
        'LOGIN: exception=$e',
      );

      debugPrint('========================================');

      rethrow;
    }
  }

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/auth/register.php',
    );

    debugPrint('REGISTER: starting');
    debugPrint('REGISTER: URL=$uri');
    debugPrint(
      'REGISTER: username=${username.trim()}',
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username.trim(),
          'password': password,

          // Honeypot anti-bot field
          'website': '',
        }),
      );

      debugPrint(
        'REGISTER: status=${response.statusCode}',
      );

      final responseData =
          _decodeResponse(response);

      debugPrint(
        'REGISTER: success=${responseData['success']}',
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['success'] == true) {
        debugPrint(
          'REGISTER: successful',
        );

        return Map<String, dynamic>.from(
          responseData['data'] ?? {},
        );
      }

      final message =
          responseData['message']?.toString() ??
              'สมัครสมาชิกไม่สำเร็จ';

      debugPrint(
        'REGISTER: error=$message',
      );

      throw Exception(message);
    } catch (e) {
      debugPrint(
        'REGISTER: exception=$e',
      );

      rethrow;
    }
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      throw Exception(
        'ยังไม่ได้เข้าสู่ระบบ',
      );
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/auth/me.php',
    );

    debugPrint(
      'AUTH ME: checking current user',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'AUTH ME: status=${response.statusCode}',
      );

      final responseData =
          _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['success'] == true) {
        final data =
            Map<String, dynamic>.from(
          responseData['data'] ?? {},
        );

        final user = data['user'];

        if (user is Map) {
          _currentUser =
              Map<String, dynamic>.from(user);

          debugPrint(
            'AUTH ME: user=${_currentUser?['username']}',
          );
        }

        return data;
      }

      if (response.statusCode == 401) {
        debugPrint(
          'AUTH ME: session invalid or expired',
        );

        _clearLocalSession();

        throw Exception(
          responseData['message'] ??
              'Session หมดอายุ กรุณาเข้าสู่ระบบใหม่',
        );
      }

      throw Exception(
        responseData['message']?.toString() ??
            'ไม่สามารถตรวจสอบผู้ใช้ได้',
      );
    } catch (e) {
      debugPrint(
        'AUTH ME: exception=$e',
      );

      rethrow;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      debugPrint(
        'LOGOUT: no active session',
      );

      _clearLocalSession();
      return;
    }

    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/auth/logout.php',
      );

      debugPrint(
        'LOGOUT: sending request',
      );

      final response = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'LOGOUT: status=${response.statusCode}',
      );

      // ไม่ว่าจะ Server ตอบอะไร
      // ฝั่ง App ต้องล้าง token
      if (response.statusCode >= 200 &&
          response.statusCode < 500) {
        _clearLocalSession();

        debugPrint(
          'LOGOUT: local session cleared',
        );

        return;
      }

      _clearLocalSession();
    } catch (e) {
      debugPrint(
        'LOGOUT: exception=$e',
      );

      // Network error:
      // ล้าง session ฝั่ง App เพื่อความปลอดภัย
      _clearLocalSession();
    }
  }

  // ============================================================
  // CLEAR SESSION
  // ============================================================

  static void clearSession() {
    _clearLocalSession();
  }

  static void _clearLocalSession() {
    _token = null;
    _currentUser = null;

    debugPrint(
      'AUTH: local session cleared',
    );
  }

  // ============================================================
  // HTTP RESPONSE DECODER
  // ============================================================

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Server returned an empty response',
      };
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'success': false,
        'message': 'รูปแบบข้อมูลจาก Server ไม่ถูกต้อง',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'ไม่สามารถอ่านข้อมูลจาก Server ได้',
      };
    }
  }
}