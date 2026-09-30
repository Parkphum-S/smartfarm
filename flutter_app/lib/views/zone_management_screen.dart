import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ZoneManagementScreen extends StatefulWidget {
  const ZoneManagementScreen({super.key});

  @override
  State<ZoneManagementScreen> createState() => _ZoneManagementScreenState();
}

class _ZoneManagementScreenState extends State<ZoneManagementScreen> {
  late Future<List<dynamic>> _zonesFuture;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  void _loadZones() {
    setState(() {
      _zonesFuture = ApiService.getZones();
    });
  }

  void _showAddZoneDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    String zoneType = 'vegetable';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มโซนใหม่ในฟาร์ม'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'รหัสโซน (เช่น zone_07)'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'ชื่อโซน (เช่น แปลงทดลอง)'),
            ),
            TextField(
              controller: TextEditingController(text: zoneType),
              onChanged: (val) => zoneType = val,
              decoration: const InputDecoration(labelText: 'ประเภทโซน (เช่น vegetable, fruit)'),
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
                bool success = await ApiService.createZone(
                  code: codeController.text,
                  name: nameController.text,
                  zoneType: zoneType,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (success) {
                  _loadZones();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เพิ่มโซนสำเร็จ'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เพิ่มโซนไม่สำเร็จ'), backgroundColor: Colors.red),
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
        title: const Text('Zone Management'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _zonesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ยังไม่มีข้อมูลโซนในระบบ'));
          }

          final zones = snapshot.data!;
          return ListView.builder(
            itemCount: zones.length,
            itemBuilder: (context, index) {
              final zone = zones[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.layers, color: Colors.green),
                  title: Text(zone['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Code: ${zone['code']} | Type: ${zone['zone_type']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      bool success = await ApiService.deleteZone(int.parse(zone['id'].toString()));
                      if (success) {
                        _loadZones();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ลบโซนเรียบร้อยแล้ว')),
                        );
                      }
                    },
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
        onPressed: _showAddZoneDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}