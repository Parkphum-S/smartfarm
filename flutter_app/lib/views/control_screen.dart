import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool _isPumpOn = false;
  bool _isLoading = false;

  void _togglePump(bool value) async {
    setState(() {
      _isLoading = true;
    });

    String action = value ? 'on' : 'off';
    // ตัวอย่างการควบคุมปั๊มหลักใน zone_01
    bool success = await ApiService.sendActuatorCommand(
      actuatorId: 'irrigation_pump_001',
      action: action,
      zoneId: 'zone_01',
    );

    setState(() {
      _isLoading = false;
      if (success) {
        _isPumpOn = value;
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'ส่งคำสั่งสำเร็จ: ปั๊มน้ำ ${action.toUpperCase()}' : 'ส่งคำสั่งไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อ'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Manual Control'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              child: SwitchListTile(
                secondary: Icon(
                  Icons.water_drop,
                  color: _isPumpOn ? Colors.blue : Colors.grey,
                  size: 36,
                ),
                title: const Text(
                  'Main Irrigation Pump (Zone 01)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text(_isPumpOn ? 'สถานะ: กำลังทำงาน (ON)' : 'สถานะ: ปิดอยู่ (OFF)'),
                value: _isPumpOn,
                onChanged: _isLoading ? null : _togglePump,
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}