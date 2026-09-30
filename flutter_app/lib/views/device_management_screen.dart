import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  late Future<List<dynamic>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() {
    setState(() {
      _devicesFuture = ApiService.getEsp32Devices();
    });
  }

  void _showAddDeviceDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลงทะเบียน ESP32 ใหม่'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Device Code (เช่น esp32_001)'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'ชื่ออุปกรณ์ (เช่น Gateway แปลงผัก)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (codeController.text.isNotEmpty && nameController.text.isNotEmpty) {
                bool success = await ApiService.registerEsp32Device(
                  code: codeController.text,
                  name: nameController.text,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (success) {
                  _loadDevices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ลงทะเบียนอุปกรณ์สำเร็จ'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ลงทะเบียนไม่สำเร็จ'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Device Management'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ยังไม่มีข้อมูลอุปกรณ์ ESP32 ในระบบ'));
          }

          final devices = snapshot.data!;
          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final dev = devices[index];
              bool isOnline = dev['status'] == 'online';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    Icons.memory,
                    color: isOnline ? Colors.green : Colors.grey,
                    size: 40,
                  ),
                  title: Text(dev['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Code: ${dev['device_code']} | IP: ${dev['ip_address'] ?? "N/A"}'),
                  trailing: Chip(
                    label: Text(dev['status'] ?? 'offline'),
                    backgroundColor: isOnline ? Colors.green.shade100 : Colors.grey.shade200,
                    labelStyle: TextStyle(color: isOnline ? Colors.green.darken : Colors.grey.darken),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        onPressed: _showAddDeviceDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

extension ColorExtension on Color {
  Color get darken => HSLColor.fromColor(this).withLightness((HSLColor.fromColor(this).lightness - 0.3).clamp(0.0, 1.0)).toColor();
}