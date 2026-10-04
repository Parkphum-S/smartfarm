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

    String selectedBoardType = 'ESP32_DEVKIT_V1';
    String selectedDeviceRole = 'CONTROLLER';
    int? selectedZoneId;

    const deviceRoles = [
      'TEST_CONTROLLER',
      'SENSOR_NODE',
      'CONTROLLER',
      'CAMERA',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ลงทะเบียน IoT Device ใหม่'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Device Code',
                    hintText: 'เช่น ESP8266_001',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่ออุปกรณ์',
                    hintText: 'เช่น ESP8266 Sensor Node 001',
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<dynamic>>(
                  future: ApiService.getZones(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'โหลด Zone ไม่สำเร็จ: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    final zones = snapshot.data ?? [];

                    return DropdownButtonFormField<int>(
                      initialValue: selectedZoneId,
                      decoration: const InputDecoration(
                        labelText: 'Zone',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('เลือก Zone'),
                      items: zones
                          .map((zone) {
                            final id = int.tryParse('${zone['id']}');
                            final code = zone['code'] ?? 'N/A';
                            final name = zone['name'] ?? 'Unnamed Zone';

                            if (id == null) {
                              return null;
                            }

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text('$code - $name'),
                            );
                          })
                          .whereType<DropdownMenuItem<int>>()
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedZoneId = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<dynamic>>(
                  future: ApiService.getDeviceBoardTypes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ไม่สามารถโหลดรายการ Board Type ได้',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final boardTypes = snapshot.data ?? [];

                    return DropdownButtonFormField<String>(
                      initialValue:
                          boardTypes.any(
                            (board) => board['code'] == selectedBoardType,
                          )
                          ? selectedBoardType
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Board Type',
                        border: OutlineInputBorder(),
                      ),
                      items: boardTypes
                          .map(
                            (board) => DropdownMenuItem<String>(
                              value: board['code']?.toString(),
                              child: Text(
                                board['name']?.toString() ??
                                    board['code']?.toString() ??
                                    '',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedBoardType = value;
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDeviceRole,
                  decoration: const InputDecoration(
                    labelText: 'Device Role',
                    border: OutlineInputBorder(),
                  ),
                  items: deviceRoles
                      .map(
                        (role) =>
                            DropdownMenuItem(value: role, child: Text(role)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedDeviceRole = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                debugPrint('REGISTER DEVICE: button pressed');
                debugPrint(
                  'REGISTER DEVICE: code=${codeController.text.trim()}',
                );
                debugPrint(
                  'REGISTER DEVICE: name=${nameController.text.trim()}',
                );
                debugPrint('REGISTER DEVICE: zoneId=$selectedZoneId');
                debugPrint('REGISTER DEVICE: boardType=$selectedBoardType');
                debugPrint('REGISTER DEVICE: deviceRole=$selectedDeviceRole');

                if (codeController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty) {
                  debugPrint('REGISTER DEVICE: validation failed');
                  return;
                }

                final success = await ApiService.registerEsp32Device(
                  code: codeController.text.trim(),
                  name: nameController.text.trim(),
                  zoneId: selectedZoneId,
                  boardType: selectedBoardType,
                  deviceRole: selectedDeviceRole,
                );

                if (!context.mounted) return;

                Navigator.pop(dialogContext);

                if (success) {
                  _loadDevices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ลงทะเบียนอุปกรณ์สำเร็จ'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ลงทะเบียนไม่สำเร็จ'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDevice(Map<String, dynamic> device) async {
    final deviceId = int.tryParse('${device['id'] ?? ''}');
    if (deviceId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบ Device ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final deviceCode = device['device_code'] ?? 'N/A';
    final deviceName = device['name'] ?? 'N/A';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ Device'),
        content: Text(
          'คุณต้องการลบ Device นี้หรือไม่?\n\n'
          'Code: $deviceCode\n'
          'Name: $deviceName\n\n'
          'คำเตือน: Sensor, Sensor Reading, Actuator, '
          'Device Command และ Device State ที่ผูกกับ Device นี้ '
          'จะถูกลบตามระบบฐานข้อมูล',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ Device'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await ApiService.deleteEsp32Device(deviceId);

    if (!mounted) return;

    if (success) {
      _loadDevices();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบ Device สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถลบ Device ได้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditDeviceDialog(Map<String, dynamic> device) {
    final codeController = TextEditingController(
      text: device['device_code']?.toString() ?? '',
    );
    final nameController = TextEditingController(
      text: device['name']?.toString() ?? '',
    );

    int? selectedZoneId = int.tryParse(device['zone_id']?.toString() ?? '');
    String? selectedBoardType = device['board_type']?.toString();
    String? selectedDeviceRole = device['device_role']?.toString();

    const deviceRoles = [
      'TEST_CONTROLLER',
      'SENSOR_NODE',
      'CONTROLLER',
      'CAMERA',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('แก้ไข IoT Device'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Device Code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่ออุปกรณ์',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<dynamic>>(
                  future: ApiService.getZones(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'โหลด Zone ไม่สำเร็จ: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    final zones = snapshot.data ?? [];

                    return DropdownButtonFormField<int>(
                      initialValue:
                          zones.any(
                            (zone) =>
                                int.tryParse('${zone['id']}') == selectedZoneId,
                          )
                          ? selectedZoneId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Zone',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('ไม่ระบุ Zone'),
                      items: zones
                          .map((zone) {
                            final id = int.tryParse('${zone['id']}');

                            if (id == null) return null;

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                '${zone['code'] ?? 'N/A'} - '
                                '${zone['name'] ?? 'Unnamed Zone'}',
                              ),
                            );
                          })
                          .whereType<DropdownMenuItem<int>>()
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedZoneId = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<dynamic>>(
                  future: ApiService.getDeviceBoardTypes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ไม่สามารถโหลดรายการ Board Type ได้',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final boardTypes = snapshot.data ?? [];

                    return DropdownButtonFormField<String>(
                      initialValue:
                          boardTypes.any(
                            (board) =>
                                board['code']?.toString() == selectedBoardType,
                          )
                          ? selectedBoardType
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Board Type',
                        border: OutlineInputBorder(),
                      ),
                      items: boardTypes
                          .map(
                            (board) => DropdownMenuItem<String>(
                              value: board['code']?.toString(),
                              child: Text(
                                board['name']?.toString() ??
                                    board['code']?.toString() ??
                                    '',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedBoardType = value;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: deviceRoles.contains(selectedDeviceRole)
                      ? selectedDeviceRole
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Device Role',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('เลือก Device Role'),
                  items: deviceRoles
                      .map(
                        (role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDeviceRole = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (codeController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty) {
                  return;
                }

                final deviceId = int.tryParse(device['id']?.toString() ?? '');

                if (deviceId == null) return;

                final success = await ApiService.updateEsp32Device(
                  id: deviceId,
                  zoneId: selectedZoneId,
                  code: codeController.text.trim(),
                  name: nameController.text.trim(),
                  boardType: selectedBoardType,
                  deviceRole: selectedDeviceRole,
                );

                if (!context.mounted) return;

                Navigator.pop(dialogContext);

                if (success) {
                  _loadDevices();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('แก้ไขอุปกรณ์สำเร็จ'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('แก้ไขอุปกรณ์ไม่สำเร็จ'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Device Management'),
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
            return const Center(
              child: Text('ยังไม่มีข้อมูล IoT Device ในระบบ'),
            );
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
                  title: Text(
                    dev['name'] ?? 'Unnamed Device',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Code: ${dev['device_code'] ?? "N/A"}\n'
                    'Board: ${dev['board_type'] ?? "N/A"}\n'
                    'Role: ${dev['device_role'] ?? "N/A"}\n'
                    'IP: ${dev['ip_address'] ?? "N/A"}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'แก้ไข Device',
                        onPressed: () => _showEditDeviceDialog(dev),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'ลบ Device',
                        onPressed: () => _deleteDevice(dev),
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                      Chip(
                        label: Text(dev['status'] ?? 'offline'),
                        backgroundColor: isOnline
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        labelStyle: TextStyle(
                          color: isOnline
                              ? Colors.green.darken
                              : Colors.grey.darken,
                        ),
                      ),
                    ],
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
  Color get darken => HSLColor.fromColor(this)
      .withLightness((HSLColor.fromColor(this).lightness - 0.3).clamp(0.0, 1.0))
      .toColor();
}
