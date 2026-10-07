import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class SensorManagementScreen extends StatefulWidget {
  const SensorManagementScreen({super.key});

  @override
  State<SensorManagementScreen> createState() => _SensorManagementScreenState();
}

class _SensorManagementScreenState extends State<SensorManagementScreen> {
  late Future<List<dynamic>> _sensorsFuture;
  late Future<List<dynamic>> _zonesFuture;
  late Future<List<dynamic>> _devicesFuture;
  late Future<List<dynamic>> _sensorTypesFuture;
  late Future<List<dynamic>> _sensorInterfacesFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _sensorsFuture = ApiService.getSensors();
    _zonesFuture = ApiService.getZones();
    _devicesFuture = ApiService.getEsp32Devices();
    _sensorTypesFuture = ApiService.getSensorTypes();
    _sensorInterfacesFuture = ApiService.getSensorInterfaces();
  }

  Future<void> _refresh() async {
    setState(_loadData);
    await _sensorsFuture;
  }

  Future<void> _deleteSensor(Map<String, dynamic> sensor) async {
    final sensorId = int.tryParse(sensor['id']?.toString() ?? '');
    if (sensorId == null) return;

    final sensorName =
        sensor['name']?.toString() ?? sensor['sensor_code']?.toString() ?? '-';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ Sensor'),
          content: Text(
            'คุณต้องการลบ Sensor "$sensorName" ใช่หรือไม่?\n\n'
            'การลบนี้ไม่สามารถย้อนกลับได้',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('ลบ Sensor'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final success = await ApiService.deleteSensor(sensorId);

    if (!mounted) return;

    if (success) {
      await _refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบ Sensor สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบ Sensor ไม่สำเร็จ กรุณาลองใหม่'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditSensorDialog(Map<String, dynamic> sensor) {
    final codeController = TextEditingController(
      text: sensor['sensor_code']?.toString() ?? '',
    );
    final nameController = TextEditingController(
      text: sensor['name']?.toString() ?? '',
    );
    final hardwareController = TextEditingController(
      text: sensor['hardware_identifier']?.toString() ?? '',
    );
    final samplingController = TextEditingController(
      text: sensor['sampling_interval_seconds']?.toString() ?? '300',
    );

    int? selectedZoneId = int.tryParse(sensor['zone_id']?.toString() ?? '');
    int? selectedDeviceId = int.tryParse(
      sensor['esp32_device_id']?.toString() ?? '',
    );
    int? selectedSensorTypeId = int.tryParse(
      sensor['sensor_type_id']?.toString() ?? '',
    );
    String selectedInterfaceType =
        sensor['interface_type']?.toString() ?? 'gpio';
    String selectedStatus = sensor['status']?.toString() ?? 'active';

    Map<String, dynamic> connectionConfig = {};
    Map<String, dynamic> selectedConfigSchema = {};

    final rawConfig = sensor['connection_config_json'];
    if (rawConfig is String && rawConfig.trim().isNotEmpty) {
      try {
        final decoded = json.decode(rawConfig);
        if (decoded is Map<String, dynamic>) {
          connectionConfig = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        connectionConfig = {};
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('แก้ไข Sensor'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: FutureBuilder<List<dynamic>>(
                    future: Future.wait([
                      _zonesFuture,
                      _devicesFuture,
                      _sensorTypesFuture,
                      _sensorInterfacesFuture,
                    ]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Text(
                          'ไม่สามารถโหลดข้อมูลสำหรับแก้ไข Sensor ได้\n'
                          '${snapshot.error}',
                        );
                      }

                      final zones = snapshot.data![0];
                      final devices = snapshot.data![1];
                      final sensorTypes = snapshot.data![2];
                      final sensorInterfaces = snapshot.data![3];

                      final availableInterfaceCodes = sensorInterfaces
                          .map((item) => item['code']?.toString())
                          .whereType<String>()
                          .toSet();

                      final safeSelectedInterfaceType =
                          availableInterfaceCodes.contains(
                            selectedInterfaceType,
                          )
                          ? selectedInterfaceType
                          : null;

                      if (selectedConfigSchema.isEmpty) {
                        final matchingInterfaces = sensorInterfaces
                            .cast<Map<String, dynamic>>()
                            .where(
                              (item) =>
                                  item['code']?.toString() ==
                                  selectedInterfaceType,
                            )
                            .toList();

                        final selectedInterface = matchingInterfaces.isEmpty
                            ? null
                            : matchingInterfaces.first;

                        final rawSchema =
                            selectedInterface?['config_schema_json'];

                        if (rawSchema is String &&
                            rawSchema.trim().isNotEmpty) {
                          try {
                            final decoded = json.decode(rawSchema);
                            if (decoded is Map<String, dynamic>) {
                              selectedConfigSchema = decoded;
                            }
                          } catch (_) {
                            selectedConfigSchema = {};
                          }
                        }
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: selectedZoneId,
                            decoration: const InputDecoration(
                              labelText: 'Zone',
                              border: OutlineInputBorder(),
                            ),
                            items: zones.map<DropdownMenuItem<int>>((zone) {
                              final id = int.tryParse(zone['id'].toString());

                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '${zone['zone_code'] ?? zone['name'] ?? id}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedZoneId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: selectedDeviceId,
                            decoration: const InputDecoration(
                              labelText: 'IoT Device',
                              border: OutlineInputBorder(),
                            ),
                            items: devices.map<DropdownMenuItem<int>>((device) {
                              final id = int.tryParse(device['id'].toString());

                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  device['name']?.toString() ??
                                      device['device_code']?.toString() ??
                                      '$id',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedDeviceId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: selectedSensorTypeId,
                            decoration: const InputDecoration(
                              labelText: 'Sensor Type',
                              border: OutlineInputBorder(),
                            ),
                            items: sensorTypes.map<DropdownMenuItem<int>>((
                              type,
                            ) {
                              final id = int.tryParse(type['id'].toString());

                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '${type['name']}'
                                  '${type['default_unit'] != null ? ' (${type['default_unit']})' : ''}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedSensorTypeId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: safeSelectedInterfaceType,
                            decoration: const InputDecoration(
                              labelText: 'Interface Type',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              if (selectedInterfaceType == 'camera')
                                const DropdownMenuItem<String>(
                                  value: 'camera',
                                  child: Text('Camera (Special)'),
                                ),
                              ...sensorInterfaces.map<
                                DropdownMenuItem<String>
                              >((interface) {
                                final code = interface['code']?.toString();

                                return DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(
                                    '${interface['name']}'
                                    '${interface['protocol'] != null ? ' (${interface['protocol']})' : ''}',
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              if (value == null) return;

                              final selectedInterface = sensorInterfaces
                                  .cast<Map<String, dynamic>>()
                                  .where(
                                    (item) => item['code']?.toString() == value,
                                  )
                                  .firstOrNull;

                              Map<String, dynamic> schema = {};
                              final rawSchema =
                                  selectedInterface?['config_schema_json'];

                              if (rawSchema is String &&
                                  rawSchema.trim().isNotEmpty) {
                                try {
                                  final decoded = json.decode(rawSchema);
                                  if (decoded is Map<String, dynamic>) {
                                    schema = decoded;
                                  }
                                } catch (_) {
                                  schema = {};
                                }
                              }

                              setDialogState(() {
                                selectedInterfaceType = value;
                                selectedConfigSchema = schema;
                                connectionConfig = {};
                              });
                            },
                          ),
                          if (selectedConfigSchema['fields'] is List) ...[
                            const SizedBox(height: 12),
                            ...((selectedConfigSchema['fields'] as List)
                                .whereType<Map<String, dynamic>>()
                                .map((field) {
                                  final key = field['key']?.toString() ?? '';
                                  final label =
                                      field['label']?.toString() ?? key;
                                  final type =
                                      field['type']?.toString() ?? 'string';
                                  final required = field['required'] == true;

                                  if (key.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextField(
                                      controller: TextEditingController(
                                        text:
                                            connectionConfig[key]?.toString() ??
                                            '',
                                      ),
                                      keyboardType: type == 'integer'
                                          ? TextInputType.number
                                          : TextInputType.text,
                                      decoration: InputDecoration(
                                        labelText:
                                            '$label${required ? ' *' : ''}',
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        if (value.trim().isEmpty) {
                                          connectionConfig.remove(key);
                                          return;
                                        }

                                        connectionConfig[key] =
                                            type == 'integer'
                                            ? int.tryParse(value.trim())
                                            : value.trim();
                                      },
                                    ),
                                  );
                                })),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: codeController,
                            decoration: const InputDecoration(
                              labelText: 'Sensor Code',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อ Sensor',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: hardwareController,
                            decoration: const InputDecoration(
                              labelText: 'Hardware Identifier',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: samplingController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sampling Interval (วินาที)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('Active'),
                              ),
                              DropdownMenuItem(
                                value: 'inactive',
                                child: Text('Inactive'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedStatus = value;
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
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
                    final samplingInterval = int.tryParse(
                      samplingController.text.trim(),
                    );

                    if (selectedZoneId == null ||
                        selectedDeviceId == null ||
                        selectedSensorTypeId == null ||
                        codeController.text.trim().isEmpty ||
                        nameController.text.trim().isEmpty ||
                        samplingInterval == null ||
                        samplingInterval <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final requiredConfigFields =
                        selectedConfigSchema['fields'] is List
                        ? (selectedConfigSchema['fields'] as List)
                              .whereType<Map<String, dynamic>>()
                              .where((field) => field['required'] == true)
                              .toList()
                        : <Map<String, dynamic>>[];

                    final missingConfigField = requiredConfigFields
                        .cast<Map<String, dynamic>?>()
                        .firstWhere((field) {
                          final key = field?['key']?.toString() ?? '';
                          final value = connectionConfig[key];
                          return key.isEmpty ||
                              value == null ||
                              value.toString().trim().isEmpty;
                        }, orElse: () => null);

                    if (missingConfigField != null) {
                      final label =
                          missingConfigField['label']?.toString() ??
                          missingConfigField['key']?.toString() ??
                          'Connection Config';

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('กรุณากรอก $label'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final success = await ApiService.updateSensor(
                      id: int.parse(sensor['id'].toString()),
                      zoneId: selectedZoneId!,
                      esp32DeviceId: selectedDeviceId!,
                      sensorTypeId: selectedSensorTypeId!,
                      sensorCode: codeController.text.trim(),
                      name: nameController.text.trim(),
                      hardwareIdentifier: hardwareController.text.trim().isEmpty
                          ? null
                          : hardwareController.text.trim(),
                      interfaceType: selectedInterfaceType,
                      connectionConfigJson: connectionConfig.isEmpty
                          ? null
                          : json.encode(connectionConfig),
                      unit: sensor['unit']?.toString(),
                      validMin: double.tryParse(
                        sensor['valid_min']?.toString() ?? '',
                      ),
                      validMax: double.tryParse(
                        sensor['valid_max']?.toString() ?? '',
                      ),
                      samplingIntervalSeconds: samplingInterval,
                      status: selectedStatus,
                    );

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);

                    if (success) {
                      await _refresh();

                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('แก้ไข Sensor สำเร็จ'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      if (!mounted) return;

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'แก้ไข Sensor ไม่สำเร็จ กรุณาตรวจสอบข้อมูล',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('บันทึกการแก้ไข'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddSensorDialog() {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final hardwareController = TextEditingController();
    final samplingController = TextEditingController(text: '300');

    int? selectedZoneId;
    int? selectedDeviceId;
    int? selectedSensorTypeId;
    String selectedInterfaceType = 'gpio';
    Map<String, dynamic> connectionConfig = {};
    Map<String, dynamic> selectedConfigSchema = {};

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('เพิ่ม Sensor'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: FutureBuilder<List<dynamic>>(
                    future: Future.wait([
                      _zonesFuture,
                      _devicesFuture,
                      _sensorTypesFuture,
                      _sensorInterfacesFuture,
                    ]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Text(
                          'ไม่สามารถโหลดข้อมูลสำหรับเพิ่ม Sensor ได้\n'
                          '${snapshot.error}',
                        );
                      }

                      final zones = snapshot.data![0];
                      final devices = snapshot.data![1];
                      final sensorTypes = snapshot.data![2];
                      final sensorInterfaces = snapshot.data![3];

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: selectedZoneId,
                            decoration: const InputDecoration(
                              labelText: 'Zone',
                              border: OutlineInputBorder(),
                            ),
                            items: zones.map<DropdownMenuItem<int>>((zone) {
                              final id = int.tryParse(zone['id'].toString());

                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '${zone['zone_code'] ?? zone['name'] ?? id}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedZoneId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: selectedDeviceId,
                            decoration: const InputDecoration(
                              labelText: 'IoT Device',
                              border: OutlineInputBorder(),
                            ),
                            items: devices.map<DropdownMenuItem<int>>((device) {
                              final id = int.tryParse(device['id'].toString());

                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  device['name']?.toString() ??
                                      device['device_code']?.toString() ??
                                      '$id',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedDeviceId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: selectedSensorTypeId,
                            decoration: const InputDecoration(
                              labelText: 'Sensor Type',
                              border: OutlineInputBorder(),
                            ),
                            items: sensorTypes.map<DropdownMenuItem<int>>((
                              type,
                            ) {
                              final id = int.tryParse(type['id'].toString());

                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '${type['name']}'
                                  '${type['default_unit'] != null ? ' (${type['default_unit']})' : ''}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedSensorTypeId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedInterfaceType,
                            decoration: const InputDecoration(
                              labelText: 'Interface Type',
                              border: OutlineInputBorder(),
                            ),
                            items: sensorInterfaces.map<DropdownMenuItem<String>>((
                              interface,
                            ) {
                              final code = interface['code']?.toString();

                              return DropdownMenuItem<String>(
                                value: code,
                                child: Text(
                                  '${interface['name']}'
                                  '${interface['protocol'] != null ? ' (${interface['protocol']})' : ''}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final selectedInterface = sensorInterfaces
                                  .cast<Map<String, dynamic>>()
                                  .firstWhere(
                                    (item) => item['code']?.toString() == value,
                                    orElse: () => <String, dynamic>{},
                                  );

                              Map<String, dynamic> schema = {};
                              final rawSchema =
                                  selectedInterface['config_schema_json'];

                              if (rawSchema is String &&
                                  rawSchema.trim().isNotEmpty) {
                                try {
                                  final decoded = json.decode(rawSchema);
                                  if (decoded is Map<String, dynamic>) {
                                    schema = decoded;
                                  }
                                } catch (_) {
                                  schema = {};
                                }
                              }

                              setDialogState(() {
                                selectedInterfaceType = value;
                                selectedConfigSchema = schema;
                                connectionConfig = {};
                              });

                              debugPrint(
                                'SENSOR CONFIG SCHEMA: '
                                'interface=$value schema=$schema',
                              );
                            },
                          ),
                          if (selectedConfigSchema['fields'] is List) ...[
                            const SizedBox(height: 12),
                            ...((selectedConfigSchema['fields'] as List)
                                .whereType<Map<String, dynamic>>()
                                .map((field) {
                                  final key = field['key']?.toString() ?? '';
                                  final label =
                                      field['label']?.toString() ?? key;
                                  final type =
                                      field['type']?.toString() ?? 'string';
                                  final required = field['required'] == true;

                                  if (key.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextField(
                                      keyboardType: type == 'integer'
                                          ? TextInputType.number
                                          : TextInputType.text,
                                      decoration: InputDecoration(
                                        labelText:
                                            '$label${required ? ' *' : ''}',
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        if (value.trim().isEmpty) {
                                          connectionConfig.remove(key);
                                          return;
                                        }

                                        connectionConfig[key] =
                                            type == 'integer'
                                            ? int.tryParse(value.trim())
                                            : value.trim();
                                      },
                                    ),
                                  );
                                })),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: codeController,
                            decoration: const InputDecoration(
                              labelText: 'Sensor Code',
                              hintText: 'เช่น soil_moisture_02',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อ Sensor',
                              hintText: 'เช่น Soil Moisture Sensor 02',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: hardwareController,
                            decoration: const InputDecoration(
                              labelText: 'Hardware Identifier',
                              hintText: 'เช่น GPIO34',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: samplingController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sampling Interval (วินาที)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                    final samplingInterval = int.tryParse(
                      samplingController.text.trim(),
                    );

                    if (selectedZoneId == null ||
                        selectedDeviceId == null ||
                        selectedSensorTypeId == null ||
                        codeController.text.trim().isEmpty ||
                        nameController.text.trim().isEmpty ||
                        samplingInterval == null ||
                        samplingInterval <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final requiredConfigFields =
                        selectedConfigSchema['fields'] is List
                        ? (selectedConfigSchema['fields'] as List)
                              .whereType<Map<String, dynamic>>()
                              .where((field) => field['required'] == true)
                              .toList()
                        : <Map<String, dynamic>>[];

                    final missingConfigField = requiredConfigFields
                        .cast<Map<String, dynamic>?>()
                        .firstWhere((field) {
                          final key = field?['key']?.toString() ?? '';
                          final value = connectionConfig[key];
                          return key.isEmpty ||
                              value == null ||
                              value.toString().trim().isEmpty;
                        }, orElse: () => null);

                    if (missingConfigField != null) {
                      final label =
                          missingConfigField['label']?.toString() ??
                          missingConfigField['key']?.toString() ??
                          'Connection Config';

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('กรุณากรอก $label'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final success = await ApiService.registerSensor(
                      zoneId: selectedZoneId!,
                      esp32DeviceId: selectedDeviceId!,
                      sensorTypeId: selectedSensorTypeId!,
                      sensorCode: codeController.text.trim(),
                      name: nameController.text.trim(),
                      hardwareIdentifier: hardwareController.text.trim().isEmpty
                          ? null
                          : hardwareController.text.trim(),
                      interfaceType: selectedInterfaceType,
                      connectionConfigJson: connectionConfig.isEmpty
                          ? null
                          : json.encode(connectionConfig),
                      samplingIntervalSeconds: samplingInterval,
                    );

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);

                    if (success) {
                      await _refresh();

                      if (!dialogContext.mounted) return;

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('เพิ่ม Sensor สำเร็จ'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'เพิ่ม Sensor ไม่สำเร็จ กรุณาตรวจสอบ Sensor Code',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Management'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _sensorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'เกิดข้อผิดพลาด: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final sensors = snapshot.data ?? [];

          if (sensors.isEmpty) {
            return const Center(child: Text('ยังไม่มี Sensor ในระบบ'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sensors.length,
              itemBuilder: (context, index) {
                final sensor = sensors[index];

                final sensorCode = sensor['sensor_code']?.toString() ?? '-';
                final name = sensor['name']?.toString() ?? sensorCode;
                final unit = sensor['unit']?.toString() ?? '-';
                final status = sensor['status']?.toString() ?? 'unknown';

                final isActive = status == 'active';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.sensors,
                      size: 38,
                      color: isActive ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Code: $sensorCode\nUnit: $unit'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(status),
                          backgroundColor: isActive
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                        ),
                        IconButton(
                          tooltip: 'แก้ไข Sensor',
                          onPressed: () => _showEditSensorDialog(sensor),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: 'ลบ Sensor',
                          onPressed: () => _deleteSensor(sensor),
                          icon: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        onPressed: _showAddSensorDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
