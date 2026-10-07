import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SseService {
  // กำหนด URL ของ SSE Endpoint บน Raspberry Pi ตามโครงสร้างเดิม
  final String url = 'http://192.168.1.60/api/v1/realtime/stream.php';

  Stream<Map<String, dynamic>> connectToRealtimeStream({
    int? zoneId,
  }) async* {
    debugPrint('SSE: connectToRealtimeStream() START zoneId=$zoneId');

    final client = http.Client();

    try {
      debugPrint('SSE: creating HTTP request');

      final Uri streamUri = Uri.parse(url).replace(
        queryParameters: zoneId == null
            ? null
            : <String, String>{
                'zone_id': zoneId.toString(),
              },
      );

      final request = http.Request('GET', streamUri);

      debugPrint('SSE: sending request to $streamUri');
      final response = await client.send(request);

      debugPrint('SSE: response received');
      debugPrint('SSE: statusCode=${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('SSE: HTTP 200 OK');
        debugPrint('SSE: starting response stream');

        yield* response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .where((line) => line.startsWith('data:'))
            .map((line) {
          debugPrint('SSE: received line');

          final jsonString = line.substring(5).trim();

          debugPrint('SSE: JSON=$jsonString');

          try {
            final data = jsonDecode(jsonString) as Map<String, dynamic>;

            debugPrint('SSE: JSON parsed successfully');

            return data;
          } catch (e) {
            debugPrint('SSE: JSON parse error=$e');
            return <String, dynamic>{};
          }
        }).where((data) => data.isNotEmpty);
      } else {
        debugPrint('SSE: unexpected HTTP status=${response.statusCode}');
      }
    } catch (e) {
      debugPrint('SSE: CONNECTION ERROR=$e');

      yield {
        "error": e.toString(),
      };
    } finally {
      debugPrint('SSE: closing HTTP client');
      client.close();
    }
  }
}