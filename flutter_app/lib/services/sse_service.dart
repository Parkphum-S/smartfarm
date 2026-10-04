import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SseService {
  // กำหนด URL ของ SSE Endpoint บน Raspberry Pi ตามโครงสร้างเดิม
  final String url = 'http://192.168.1.60/api/v1/realtime/stream.php';

  Stream<Map<String, dynamic>> connectToRealtimeStream() async* {
    var client = http.Client();
    try {
      var request = http.Request('GET', Uri.parse(url));
      var response = await client.send(request);

      if (response.statusCode == 200) {
        yield* response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .where((line) => line.startsWith('data:'))
            .map((line) {
          // ตัดคำว่า 'data:' ออกเพื่อแปลงเป็น JSON
          final jsonString = line.substring(5).trim();
          try {
            return jsonDecode(jsonString) as Map<String, dynamic>;
          } catch (e) {
            return <String, dynamic>{};
          }
        }).where((data) => data.isNotEmpty);
      }
    } catch (e) {
      yield* Stream.value({"error": e.toString()});
    } finally {
      client.close();
    }
  }
}