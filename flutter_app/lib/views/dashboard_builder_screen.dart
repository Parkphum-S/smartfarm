import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soil_test_screen.dart';
import 'actuator_history_screen.dart';
import 'zone_management_screen.dart';
import 'profile_screen.dart';
import 'device_sensor_management_screen.dart';
import '../services/api_service.dart';
import '../services/sse_service.dart';

class AiSafetyResult {
  final bool allowed;
  final String reason;

  const AiSafetyResult({required this.allowed, required this.reason});
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  // ============================================================
  // DASHBOARD STATE
  // ============================================================

  /// Zone ที่โหลดมาจาก API จริง
  List<dynamic> _zones = [];
  Map<int, dynamic> _latestSoilTestByZone = {};

  /// null = All Zones
  /// ตัวเลข = id ของ Zone ที่เลือก
  int? _selectedZoneId;

  /// สถานะการโหลด Zone
  bool _zonesLoading = true;

  /// Actuator ที่โหลดจาก API จริง
  List<dynamic> _actuators = [];

  /// Sensor ที่โหลดจาก API จริง
  List<dynamic> _sensors = [];

  /// สถานะการโหลด Sensor
  bool _sensorsLoading = true;

  /// สถานะการโหลด Actuator
  bool _actuatorsLoading = true;

  /// Error จาก Actuator API
  String? _actuatorsError;

  /// สถานะของ Water Pump
  bool _waterPumpOn = false;

  /// ป้องกันการกดซ้ำระหว่างส่งคำสั่ง Water Pump
  bool _waterPumpCommandLoading = false;

  /// สถานะของ Water Pump Out
  bool _waterPumpOutOn = false;

  /// ป้องกันการกดซ้ำระหว่างส่งคำสั่ง Water Pump Out
  bool _waterPumpOutCommandLoading = false;

  /// Error จาก Zone API
  String? _zonesError;

  // ============================================================
  // REAL-TIME SENSOR STATE
  // ============================================================

  /// เก็บค่าตามโครงสร้าง:
  ///
  /// {
  ///   zone_id: {
  ///     'sensor_code': value,
  ///   }
  /// }
  final Map<int, Map<String, double>> _sensorValuesByZone = {};
  final Map<int, Map<String, String>> _sensorQualityByZone = {};

  // ============================================================
  // SSE CONNECTION STATE
  // ============================================================

  /// สถานะการเชื่อมต่อ SSE
  bool _sseConnected = false;

  /// เก็บ subscription เพื่อยกเลิกเมื่อออกจากหน้า
  StreamSubscription<Map<String, dynamic>>? _sseSubscription;

  /// Timer สำหรับ reconnect SSE
  Timer? _sseReconnectTimer;

  /// จำนวนครั้งที่พยายาม reconnect SSE
  int _sseReconnectAttempt = 0;

  /// เวลาที่ได้รับ Sensor data ล่าสุด
  DateTime? _lastUpdate;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    /// โหลด Zone จาก API
    _loadZones();

    _loadSensors();

    /// โหลด Actuator และสถานะจริงจาก API
    _loadActuators();

    /// เชื่อมต่อ SSE
    _connectSse();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _sseSubscription = null;

    _sseReconnectTimer?.cancel();
    _sseReconnectTimer = null;

    super.dispose();
  }

  // ============================================================
  // ZONE ACTUATOR MAPPING
  // ============================================================

  String? _getSelectedZoneCode() {
    final int? zoneId = _selectedZoneId;

    if (zoneId == null) {
      return null;
    }

    for (final dynamic zone in _zones) {
      if (_getZoneId(zone) == zoneId) {
        final String code = zone['code']?.toString() ?? '';
        return code.isNotEmpty ? code : null;
      }
    }

    return null;
  }

  String? _getZoneActuatorCode({
    required String actuatorType,
  }) {
    final int? zoneId = _selectedZoneId;

    if (zoneId == null) {
      return null;
    }

    for (final dynamic actuator in _actuators) {
      final int? actuatorZoneId =
          int.tryParse(actuator['zone_id']?.toString() ?? '');

      if (actuatorZoneId != zoneId) {
        continue;
      }

      final String code =
          actuator['actuator_code']?.toString() ?? '';

      if (actuatorType == 'water_pump_in' &&
          code == 'water_pump_in_001') {
        return code;
      }

      if (actuatorType == 'water_pump_out' &&
          code == 'water_pump_out_001') {
        return code;
      }

      if (zoneId == 1 && actuatorType == 'water_pump_in' &&
          code == 'water_pump_01') {
        return code;
      }

      if (zoneId == 1 && actuatorType == 'water_pump_out' &&
          code == 'oxygen_pump_01') {
        return code;
      }
    }

    return null;
  }

  // ============================================================
  // REAL WATER PUMP CONTROL
  // ============================================================

  Future<void> _setWaterPump(bool value) async {
    if (_waterPumpCommandLoading) {
      return;
    }

    final String? zoneCode = _getSelectedZoneCode();
    final String? actuatorCode = _getZoneActuatorCode(
      actuatorType: 'water_pump_in',
    );

    if (zoneCode == null || actuatorCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Water Pump In: Actuator unavailable for selected zone'),
        ),
      );
      return;
    }

    setState(() {
      _waterPumpCommandLoading = true;
    });

    final bool success = await ApiService.sendActuatorCommand(
      actuatorId: actuatorCode,
      action: value ? 'on' : 'off',
      zoneId: zoneCode,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _waterPumpCommandLoading = false;

      if (success) {
        _waterPumpOn = value;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Water Pump In ${value ? "ON" : "OFF"} command sent'
              : 'Water Pump In command failed',
        ),
      ),
    );
  }

  // ============================================================
  // REAL WATER PUMP OUT CONTROL
  // ============================================================

  Future<void> _setWaterPumpOut(bool value) async {
    if (_waterPumpOutCommandLoading) {
      return;
    }

    final String? zoneCode = _getSelectedZoneCode();
    final String? actuatorCode = _getZoneActuatorCode(
      actuatorType: 'water_pump_out',
    );

    if (zoneCode == null || actuatorCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Water Pump Out: Actuator unavailable for selected zone'),
        ),
      );
      return;
    }

    setState(() {
      _waterPumpOutCommandLoading = true;
    });

    final bool success = await ApiService.sendActuatorCommand(
      actuatorId: actuatorCode,
      action: value ? 'on' : 'off',
      zoneId: zoneCode,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _waterPumpOutCommandLoading = false;

      if (success) {
        _waterPumpOutOn = value;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Water Pump Out ${value ? "ON" : "OFF"} command sent'
              : 'Water Pump Out command failed',
        ),
      ),
    );
  }

  // ============================================================
  // LOAD ZONES FROM API
  // ============================================================

  Future<void> _loadZones() async {
    try {
      if (mounted) {
        setState(() {
          _zonesLoading = true;
          _zonesError = null;
        });
      }

      final List<dynamic> zones = await ApiService.getZones();

      if (!mounted) {
        return;
      }

      setState(() {
        _zones = zones;
        _zonesLoading = false;

        /// null = All Zones
        _selectedZoneId = null;
      });

      await _loadLatestSoilTests();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _zonesLoading = false;
        _zonesError = e.toString();
      });
    }
  }

  // ============================================================
  // LOAD ACTUATORS FROM API
  // ============================================================

  Future<void> _loadSensors() async {
    try {
      if (mounted) {
        setState(() {
          _sensorsLoading = true;
        });
      }

      final List<dynamic> sensors = await ApiService.getSensors();

      if (!mounted) {
        return;
      }

      setState(() {
        _sensors = sensors;
        _sensorsLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sensors = [];
        _sensorsLoading = false;
      });
    }
  }

  Future<void> _loadActuators() async {
    try {
      if (mounted) {
        setState(() {
          _actuatorsLoading = true;
          _actuatorsError = null;
        });
      }

      final List<dynamic> actuators = await ApiService.getActuators();

      if (!mounted) {
        return;
      }

      setState(() {
        _actuators = actuators;
        _actuatorsLoading = false;

        for (final dynamic actuator in actuators) {
          final String? actuatorCode = actuator['actuator_code']?.toString();

          final String? actualState = actuator['actual_state']?.toString();

          final int? actuatorZoneId =
              int.tryParse(actuator['zone_id']?.toString() ?? '');

          if (actuatorZoneId != _selectedZoneId) {
            continue;
          }

          if (actuatorCode == 'water_pump_01' ||
              actuatorCode == 'water_pump_in_001') {
            _waterPumpOn = actualState == 'on';
          }

          if (actuatorCode == 'oxygen_pump_01' ||
              actuatorCode == 'water_pump_out_001') {
            _waterPumpOutOn = actualState == 'on';
          }
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actuatorsLoading = false;
        _actuatorsError = e.toString();
      });
    }
  }

  // ============================================================
  // SSE CONNECTION
  // ============================================================

  Future<void> _connectSse() async {
    /// ป้องกัน subscription ซ้ำ
    await _sseSubscription?.cancel();
    _sseSubscription = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _sseConnected = false;
    });

    final SseService sseService = SseService();

    _sseSubscription = sseService
        .connectToRealtimeStream(zoneId: _selectedZoneId)
        .listen(
      (Map<String, dynamic> data) {
        if (!mounted) {
          return;
        }

        _handleSseData(data);
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _sseConnected = false;
        });

        debugPrint('SSE ERROR: $error');
        _scheduleSseReconnect();
      },
      onDone: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _sseConnected = false;
        });

        debugPrint('SSE DONE: connection closed');
        _scheduleSseReconnect();
      },
      cancelOnError: false,
    );
  }

  // ============================================================
  // SSE RECONNECT SCHEDULER
  // ============================================================

  void _scheduleSseReconnect() {
    if (!mounted) {
      return;
    }

    if (_sseReconnectTimer != null) {
      return;
    }

    _sseReconnectAttempt++;

    final int delaySeconds = switch (_sseReconnectAttempt) {
      1 => 2,
      2 => 4,
      3 => 8,
      4 => 16,
      _ => 30,
    };

    debugPrint(
      'SSE RECONNECT: '
      'attempt=$_sseReconnectAttempt '
      'delay=${delaySeconds}s',
    );

    _sseReconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _sseReconnectTimer = null;

      if (!mounted) {
        return;
      }

      await _connectSse();
    });
  }

  // ============================================================
  // SSE DATA HANDLER
  // ============================================================

  void _handleSseData(Map<String, dynamic> data) {
    debugPrint('DASHBOARD SSE DATA: $data');

    // ----------------------------------------------------------
    // SSE CONNECTION EVENT
    // ----------------------------------------------------------

    if (data['status'] == 'connected') {
      if (!mounted) {
        return;
      }

      setState(() {
        _sseConnected = true;
        _sseReconnectAttempt = 0;
      });

      debugPrint('SSE CONNECTED: reconnect attempt counter reset');

      return;
    }

    // ----------------------------------------------------------
    // SSE ERROR EVENT
    // ----------------------------------------------------------

    if (data.containsKey('error')) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sseConnected = false;
      });

      return;
    }

    // ----------------------------------------------------------
    // SENSOR EVENT
    // ----------------------------------------------------------

    final dynamic zoneIdValue = data['zone_id'];
    final dynamic sensorCodeValue = data['sensor_code'];
    final dynamic rawValue = data['value'];
    final dynamic qualityValue = data['quality'];

    /// ต้องมีข้อมูลสำคัญครบ
    if (zoneIdValue == null || sensorCodeValue == null || rawValue == null) {
      return;
    }

    // ----------------------------------------------------------
    // ZONE ID
    // ----------------------------------------------------------

    final int? zoneId = int.tryParse(zoneIdValue.toString());

    if (zoneId == null) {
      return;
    }

    // ----------------------------------------------------------
    // SENSOR CODE
    // ----------------------------------------------------------

    final String sensorCode = sensorCodeValue.toString();

    if (sensorCode.isEmpty) {
      return;
    }

    // ----------------------------------------------------------
    // SENSOR VALUE
    // ----------------------------------------------------------

    final double? value = double.tryParse(rawValue.toString());

    if (value == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    // ----------------------------------------------------------
    // SAVE SENSOR VALUE BY ZONE
    // ----------------------------------------------------------

    setState(() {
      _sensorValuesByZone.putIfAbsent(zoneId, () => <String, double>{});

      _sensorValuesByZone[zoneId]![sensorCode] = value;

      _sensorQualityByZone.putIfAbsent(zoneId, () => <String, String>{});

      _sensorQualityByZone[zoneId]![sensorCode] =
          qualityValue?.toString() ?? 'unknown';

      _lastUpdate = DateTime.now();

      debugPrint(
        'DASHBOARD SENSOR STATE: '
        'zone=$zoneId '
        'sensor=$sensorCode '
        'value=$value',
      );
    });
  }

  // ============================================================
  // GET SENSOR VALUE
  // ============================================================

  double? _getSensorValue(String sensorCode) {
    // ----------------------------------------------------------
    // SELECTED ZONE
    // ----------------------------------------------------------

    if (_selectedZoneId != null) {
      return _sensorValuesByZone[_selectedZoneId]?[sensorCode];
    }

    // ----------------------------------------------------------
    // ALL ZONES
    // ----------------------------------------------------------

    for (final Map<String, double> zoneSensors in _sensorValuesByZone.values) {
      final double? value = zoneSensors[sensorCode];

      if (value != null) {
        return value;
      }
    }

    return null;
  }

  String? _getSensorQuality(String sensorCode) {
    // ----------------------------------------------------------
    // SELECTED ZONE
    // ----------------------------------------------------------

    if (_selectedZoneId != null) {
      return _sensorQualityByZone[_selectedZoneId]?[sensorCode];
    }

    // ----------------------------------------------------------
    // ALL ZONES
    // ----------------------------------------------------------

    for (final Map<String, String> zoneSensors in _sensorQualityByZone.values) {
      final String? quality = zoneSensors[sensorCode];

      if (quality != null) {
        return quality;
      }
    }

    return null;
  }

  // ============================================================
  // GET ZONE DISPLAY NAME
  // ============================================================

  String _getZoneName(dynamic zone) {
    final dynamic name = zone['name'];
    final dynamic code = zone['code'];
    final dynamic id = zone['id'];

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }

    if (code != null && code.toString().trim().isNotEmpty) {
      return code.toString().trim();
    }

    return 'Zone ${id ?? ''}'.trim();
  }

  // ============================================================
  // GET ZONE ID
  // ============================================================

  int? _getZoneId(dynamic zone) {
    return int.tryParse(zone['id']?.toString() ?? '');
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 104,
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Smart Farm',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () {
                    _loadZones();
                    _loadActuators();
                    _connectSse();
                  },
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Zone Management',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ZoneManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.layers),
                ),
                IconButton(
                  tooltip: 'Soil Test',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SoilTestScreen()),
                    );
                  },
                  icon: const Icon(Icons.science),
                ),
                IconButton(
                  tooltip: 'Actuator History',
                  onPressed: _actuatorsLoading || _actuators.isEmpty
                      ? null
                      : () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return SafeArea(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: _actuators.map<Widget>((actuator) {
                                    final String actuatorCode =
                                        actuator['actuator_code']?.toString() ??
                                        '';

                                    final String actuatorName =
                                        actuator['name']?.toString() ??
                                        actuatorCode;

                                    return ListTile(
                                      leading: const Icon(Icons.history),
                                      title: Text(actuatorName),
                                      subtitle: Text(actuatorCode),
                                      onTap: () {
                                        Navigator.pop(context);

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ActuatorHistoryScreen(
                                                  actuatorId: actuatorCode,
                                                  actuatorName: actuatorName,
                                                ),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          );
                        },
                  icon: const Icon(Icons.history),
                ),
                IconButton(
                  tooltip: 'Device & Sensor Management',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeviceSensorManagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_input_component),
                ),
                IconButton(
                  tooltip: 'Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  icon: const Icon(Icons.account_circle),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildZoneSelector(),
                        const SizedBox(height: 16),
                        _buildStatusBanner(),
                        const SizedBox(height: 16),
                        _buildDashboardGrid(maxWidth),
                        const SizedBox(height: 24),
                        _buildSystemInformation(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.agriculture,
                size: 30,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMART FARM',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'IoT Agriculture Monitoring & Control',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            _buildConnectionStatus(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SSE CONNECTION STATUS
  // ============================================================

  Widget _buildConnectionStatus() {
    final Color statusColor = _sseConnected ? Colors.green : Colors.red;

    final Color backgroundColor = _sseConnected
        ? Colors.green.shade50
        : Colors.red.shade50;

    final Color borderColor = _sseConnected
        ? Colors.green.shade200
        : Colors.red.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _sseConnected ? 'SSE Connected' : 'SSE Offline',
            style: TextStyle(fontWeight: FontWeight.w600, color: statusColor),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ZONE SELECTOR
  // ============================================================

  Widget _buildZoneSelector() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Farm Zones',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_zonesLoading)
              const SizedBox(
                height: 42,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_zonesError != null)
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unable to load farm zones.',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  TextButton(onPressed: _loadZones, child: const Text('Retry')),
                ],
              )
            else
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _zones.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final bool selected = _selectedZoneId == null;

                      return ChoiceChip(
                        label: const Text('All Zones'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedZoneId = null;
                          });
                        },
                        selectedColor: Colors.green.shade600,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }

                    final dynamic zone = _zones[index - 1];

                    final int? zoneId = _getZoneId(zone);

                    final String zoneName = _getZoneName(zone);

                    final bool selected =
                        zoneId != null && _selectedZoneId == zoneId;

                    return ChoiceChip(
                      label: Text(zoneName),
                      selected: selected,
                      onSelected: (_) {
                        if (zoneId == null) {
                          return;
                        }

                        setState(() {
                          _selectedZoneId = zoneId;
                        });

                        _connectSse();
                      },
                      selectedColor: Colors.green.shade600,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            if (!_zonesLoading &&
                _zonesError == null &&
                _selectedZoneId != null) ...[
              const SizedBox(height: 10),
              Text(
                _getSelectedZoneDescription(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                'ESP32 / Sensor Status: ${_getSelectedZoneSensorStatus()}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'SSE Endpoint: ${SseService().url}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'Gateway Status: Not Reported',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED ZONE DESCRIPTION
  // ============================================================

  List<dynamic> _getSelectedZoneSensors() {
    if (_selectedZoneId == null) {
      return [];
    }

    return _sensors.where((sensor) {
      final dynamic zoneId = sensor['zone_id'];
      return zoneId != null &&
          int.tryParse(zoneId.toString()) == _selectedZoneId;
    }).toList();
  }

  String _getSelectedZoneSensorStatus() {
    final List<dynamic> sensors = _getSelectedZoneSensors();

    if (_sensorsLoading) {
      return 'Loading';
    }

    if (sensors.isEmpty) {
      return 'Offline / No Data';
    }

    final DateTime now = DateTime.now();

    for (final dynamic sensor in sensors) {
      final String? lastReadingText =
          sensor['last_reading_at']?.toString();

      if (lastReadingText == null || lastReadingText.isEmpty) {
        return 'Offline / No Data';
      }

      final DateTime? lastReading =
          DateTime.tryParse(lastReadingText.replaceFirst(' ', 'T'));

      if (lastReading == null) {
        return 'Offline / No Data';
      }

      final int samplingInterval =
          int.tryParse(
                sensor['sampling_interval_seconds']?.toString() ?? '',
              ) ??
              60;

      final int allowedAge = samplingInterval * 3;

      if (now.difference(lastReading).inSeconds > allowedAge) {
        return 'Offline';
      }
    }

    return 'Online';
  }

  String _getSelectedZoneDescription() {
    if (_selectedZoneId == null) {
      return 'Showing data from all zones.';
    }

    for (final dynamic zone in _zones) {
      final int? zoneId = _getZoneId(zone);

      if (zoneId == _selectedZoneId) {
        final String code = zone['code']?.toString() ?? '';

        if (code.isNotEmpty) {
          return 'Zone ID: $_selectedZoneId • Code: $code';
        }

        return 'Zone ID: $_selectedZoneId';
      }
    }

    return 'Zone ID: $_selectedZoneId';
  }

  // ============================================================
  // STATUS BANNER
  // ============================================================

  Widget _buildStatusBanner() {
    final bool online = _sseConnected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: online ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: online ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.check_circle : Icons.error_outline,
            color: online ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'System Normal' : 'SSE Connection Offline',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  online
                      ? 'Real-time sensor data is being received.'
                      : 'Unable to receive real-time sensor data.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLatestSoilTests() async {
    final Map<int, dynamic> latestByZone = {};

    for (final zone in _zones) {
      final int? zoneId = int.tryParse(zone['id'].toString());

      if (zoneId == null) {
        continue;
      }

      try {
        final List<dynamic> history = await ApiService.getSoilTestHistory(
          zoneId,
        );

        if (history.isNotEmpty) {
          latestByZone[zoneId] = history.first;
        }
      } catch (_) {
        // Keep dashboard usable if soil-test history is unavailable.
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _latestSoilTestByZone = latestByZone;
    });
  }

  // ============================================================
  // DASHBOARD SENSOR CODE
  // ============================================================

  String _getDashboardSensorCode(String sensorType) {
    final int? zoneId = _selectedZoneId;

    if (zoneId == null) {
      return '${sensorType}_01';
    }

    for (final dynamic zone in _zones) {
      if (_getZoneId(zone) == zoneId) {
        final String zoneCode = zone['code']?.toString() ?? '';

        if (zoneCode == 'zone_03') {
          return '${sensorType}_001';
        }

        break;
      }
    }

    return '${sensorType}_01';
  }

  // ============================================================
  // DASHBOARD GRID
  // ============================================================

  Widget _buildDashboardGrid(double availableWidth) {
    int crossAxisCount;

    if (availableWidth >= 1400) {
      crossAxisCount = 4;
    } else if (availableWidth >= 1000) {
      crossAxisCount = 3;
    } else if (availableWidth >= 650) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    final String temperatureSensorCode =
        _getDashboardSensorCode('temperature');

    final String humiditySensorCode =
        _getDashboardSensorCode('humidity');

    final String soilMoistureSensorCode =
        _getDashboardSensorCode('soil_moisture');

    final double? temperature =
        _getSensorValue(temperatureSensorCode);

    final double? humidity =
        _getSensorValue(humiditySensorCode);

    final double? soilMoisture =
        _getSensorValue(soilMoistureSensorCode);

    final String? temperatureQuality =
        _getSensorQuality(temperatureSensorCode);

    final String? humidityQuality =
        _getSensorQuality(humiditySensorCode);

    final String? soilMoistureQuality =
        _getSensorQuality(soilMoistureSensorCode);

    final double? vpd = _calculateVpd(temperature, humidity);

    final AiSafetyResult aiSafety = _evaluateAiSafety(
      temperature: temperature,
      humidity: humidity,
      soilMoisture: soilMoisture,
      temperatureQuality: temperatureQuality,
      humidityQuality: humidityQuality,
      soilMoistureQuality: soilMoistureQuality,
    );

    final dynamic latestSoilTest = _selectedZoneId != null
        ? _latestSoilTestByZone[_selectedZoneId]
        : (_latestSoilTestByZone.values.isNotEmpty
              ? _latestSoilTestByZone.values.reduce((a, b) {
                  final DateTime dateA =
                      DateTime.tryParse(a['measured_at']?.toString() ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0);

                  final DateTime dateB =
                      DateTime.tryParse(b['measured_at']?.toString() ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0);

                  return dateA.isAfter(dateB) ? a : b;
                })
              : null);

    debugPrint(
      'AI CONTEXT => '
      'zone=$_selectedZoneId, '
      'temperature=$temperature, '
      'humidity=$humidity, '
      'soilMoisture=$soilMoisture, '
      'vpd=$vpd, '
      'soilTest=$latestSoilTest',
    );

    final String aiDecision = aiSafety.allowed
        ? _getLocalAiDecision(
            temperature: temperature,
            humidity: humidity,
            soilMoisture: soilMoisture,
            vpd: vpd,
            soilTest: latestSoilTest,
          )
        : 'AI Recommendation ถูกระงับชั่วคราว\n'
              'เหตุผล: ${aiSafety.reason}';

    final String aiStatus = aiSafety.allowed
        ? _getLocalAiStatus(
            temperature: temperature,
            humidity: humidity,
            soilMoisture: soilMoisture,
            vpd: vpd,
            soilTest: latestSoilTest,
          )
        : 'Safety Blocked';

    final bool actuatorsReady =
        !_actuatorsLoading && _actuatorsError == null && _actuators.isNotEmpty;

    final List<Widget> cards = [
      // --------------------------------------------------------
      // REAL-TIME TEMPERATURE
      // --------------------------------------------------------

      _buildSensorCard(
        title: 'Temperature',
        value: _formatSensorValue(temperature),
        unit: '°C',
        icon: Icons.thermostat,
        status: temperature != null ? 'Live' : 'Waiting',
      ),

      // --------------------------------------------------------
      // REAL-TIME HUMIDITY
      // --------------------------------------------------------
      _buildSensorCard(
        title: 'Humidity',
        value: _formatSensorValue(humidity),
        unit: '%',
        icon: Icons.water_drop,
        status: humidity != null ? 'Live' : 'Waiting',
      ),

      // --------------------------------------------------------
      // REAL-TIME SOIL MOISTURE
      // --------------------------------------------------------
      _buildSensorCard(
        title: 'Soil Moisture',
        value: _formatSensorValue(soilMoisture),
        unit: '%',
        icon: Icons.grass,
        status: soilMoisture != null ? 'Live' : 'Waiting',
      ),

      // --------------------------------------------------------
      // VPD
      // --------------------------------------------------------
      _buildSensorCard(
        title: 'VPD',
        value: _formatSensorValue(vpd),
        unit: 'kPa',
        icon: Icons.air,
        status: vpd != null ? 'Calculated' : 'Waiting',
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.psychology,
              size: 32,
              color: _getAiStatusColor(aiStatus),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Recommendation',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    aiDecision,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'สถานะ: $aiStatus',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
      // --------------------------------------------------------
      // pH
      // --------------------------------------------------------
      _buildSensorCard(
        title: 'pH',
        value: latestSoilTest?['ph']?.toString() ?? '--',
        unit: '',
        icon: Icons.science,
        status: latestSoilTest != null ? 'Latest' : 'Pending',
      ),

      // --------------------------------------------------------
      // NPK
      // --------------------------------------------------------
      _buildSensorCard(
        title: 'NPK',
        value: latestSoilTest != null
            ? 'N: ${latestSoilTest['nitrogen'] ?? '--'} mg/kg\n'
                  'P: ${latestSoilTest['phosphorus'] ?? '--'} mg/kg\n'
                  'K: ${latestSoilTest['potassium'] ?? '--'} mg/kg'
            : '--',
        unit: '',
        icon: Icons.eco,
        status: latestSoilTest != null ? 'Latest' : 'Pending',
      ),

      // --------------------------------------------------------
      // WATER PUMP
      // --------------------------------------------------------
      _buildActuatorCard(
        title: 'Water Pump In',
        subtitle: actuatorsReady
            ? 'Main irrigation pump'
            : _actuatorsLoading
            ? 'Loading actuator...'
            : 'Actuator unavailable',
        icon: Icons.water,
        isOn: _waterPumpOn,
        onChanged: actuatorsReady ? _setWaterPump : null,
        loading: _waterPumpCommandLoading || _actuatorsLoading,
      ),

      // --------------------------------------------------------
      // OXYGEN PUMP
      // --------------------------------------------------------
      _buildActuatorCard(
        title: 'Water Pump Out',
        subtitle: actuatorsReady
            ? 'Fish pond oxygen'
            : _actuatorsLoading
            ? 'Loading actuator...'
            : 'Actuator unavailable',
        icon: Icons.bubble_chart,
        isOn: _waterPumpOutOn,
        onChanged: actuatorsReady ? _setWaterPumpOut : null,
        loading: _waterPumpOutCommandLoading || _actuatorsLoading,
      ),
    ];

    return SizedBox(
      width: availableWidth,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 220,
        ),
        itemBuilder: (context, index) {
          return cards[index];
        },
      ),
    );
  }

  // ============================================================
  // SENSOR VALUE FORMATTER
  // ============================================================

  String _formatSensorValue(double? value) {
    if (value == null) {
      return '--';
    }

    return value.toStringAsFixed(1);
  }

  // ============================================================
  // SENSOR CARD
  // ============================================================

  double? _calculateVpd(double? temperature, double? humidity) {
    if (temperature == null || humidity == null) {
      return null;
    }

    if (humidity < 0 || humidity > 100) {
      return null;
    }

    final double saturationVaporPressure =
        0.6108 * math.exp((17.27 * temperature) / (temperature + 237.3));

    final double vpd = saturationVaporPressure * (1 - humidity / 100);

    return vpd;
  }

  AiSafetyResult _evaluateAiSafety({
    required double? temperature,
    required double? humidity,
    required double? soilMoisture,
    required String? temperatureQuality,
    required String? humidityQuality,
    required String? soilMoistureQuality,
  }) {
    if (temperature == null) {
      return const AiSafetyResult(
        allowed: false,
        reason: 'ข้อมูล Temperature ยังไม่พร้อม',
      );
    }

    if (humidity == null) {
      return const AiSafetyResult(
        allowed: false,
        reason: 'ข้อมูล Humidity ยังไม่พร้อม',
      );
    }

    if (soilMoisture == null) {
      return const AiSafetyResult(
        allowed: false,
        reason: 'ข้อมูล Soil Moisture ยังไม่พร้อม',
      );
    }

    if (temperatureQuality != 'valid') {
      return AiSafetyResult(
        allowed: false,
        reason:
            'Temperature มีคุณภาพข้อมูลไม่พร้อมใช้งาน '
            '(quality: ${temperatureQuality ?? 'unknown'})',
      );
    }

    if (humidityQuality != 'valid') {
      return AiSafetyResult(
        allowed: false,
        reason:
            'Humidity มีคุณภาพข้อมูลไม่พร้อมใช้งาน '
            '(quality: ${humidityQuality ?? 'unknown'})',
      );
    }

    if (soilMoistureQuality != 'valid') {
      return AiSafetyResult(
        allowed: false,
        reason:
            'Soil Moisture มีคุณภาพข้อมูลไม่พร้อมใช้งาน '
            '(quality: ${soilMoistureQuality ?? 'unknown'})',
      );
    }

    return const AiSafetyResult(
      allowed: true,
      reason: 'ข้อมูล Sensor ผ่าน Safety Validation',
    );
  }

  String _getLocalAiDecision({
    required double? temperature,
    required double? humidity,
    required double? soilMoisture,
    required double? vpd,
    dynamic soilTest,
  }) {
    if (temperature == null ||
        humidity == null ||
        soilMoisture == null ||
        vpd == null) {
      return 'กำลังรอข้อมูลจากเซนเซอร์';
    }

    String decision;

    if (soilMoisture < 25 && vpd >= 1.5) {
      decision = 'ดินค่อนข้างแห้งและ VPD สูง ควรพิจารณาให้น้ำแก่พืช';
    } else if (soilMoisture < 25) {
      decision = 'ความชื้นในดินต่ำ ควรพิจารณาให้น้ำแก่พืช';
    } else if (vpd >= 2.0) {
      decision =
          'VPD สูง พืชอาจมีความต้องการน้ำเพิ่มขึ้น '
          'ควรติดตามอย่างใกล้ชิด';
    } else if (vpd >= 1.2) {
      decision =
          'VPD อยู่ในระดับปานกลาง '
          'ควรติดตามสภาพแวดล้อมของพืชต่อเนื่อง';
    } else if (soilMoisture > 80) {
      decision =
          'ความชื้นในดินสูง '
          'ควรหลีกเลี่ยงการให้น้ำโดยไม่จำเป็น';
    } else {
      decision = 'สภาพแวดล้อมโดยรวมอยู่ในเกณฑ์ค่อนข้างปกติ';
    }

    if (soilTest != null) {
      final String ph = soilTest['ph']?.toString() ?? '-';
      final String nitrogen = soilTest['nitrogen']?.toString() ?? '-';
      final String phosphorus = soilTest['phosphorus']?.toString() ?? '-';
      final String potassium = soilTest['potassium']?.toString() ?? '-';

      decision +=
          '\n\nผลตรวจดินล่าสุด: '
          'pH $ph, N $nitrogen, P $phosphorus, '
          'K $potassium mg/kg';
    }

    return decision;
  }

  String _getLocalAiStatus({
    required double? temperature,
    required double? humidity,
    required double? soilMoisture,
    required double? vpd,
    dynamic soilTest,
  }) {
    if (temperature == null ||
        humidity == null ||
        soilMoisture == null ||
        vpd == null) {
      return 'กำลังรอข้อมูล';
    }

    if (soilMoisture < 25 && vpd >= 2.0) {
      return 'ความเสี่ยงขาดน้ำสูง';
    }

    if (soilMoisture < 25 && vpd >= 1.5) {
      return 'ควรพิจารณาให้น้ำ';
    }

    if (soilMoisture < 25) {
      return 'ควรพิจารณาให้น้ำ';
    }

    if (vpd >= 2.0) {
      return 'ควรติดตาม';
    }

    if (vpd >= 1.2) {
      return 'ควรติดตาม';
    }

    if (soilMoisture > 80) {
      return 'ควรติดตาม';
    }

    if (soilTest != null) {
      return 'ปกติ (มีข้อมูลดินล่าสุด)';
    }

    return 'ปกติ';
  }

  Color _getAiStatusColor(String status) {
    switch (status) {
      case 'ปกติ':
        return Colors.green;

      case 'ควรติดตาม':
        return Colors.amber;

      case 'ควรพิจารณาให้น้ำ':
        return Colors.orange;

      case 'ความเสี่ยงขาดน้ำสูง':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required String status,
  }) {
    final bool live = status == 'Live';

    final Color statusColor = live
        ? Colors.green.shade700
        : Colors.grey.shade700;

    final Color statusBackground = live
        ? Colors.green.shade50
        : Colors.grey.shade100;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.green.shade700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (value.contains('\n'))
              const SizedBox(height: 12)
            else
              const Spacer(),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (value.contains('\n'))
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        unit,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACTUATOR CARD
  // ============================================================

  Widget _buildActuatorCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isOn,
    ValueChanged<bool>? onChanged,
    bool loading = false,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isOn ? Colors.green.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isOn ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(value: isOn, onChanged: onChanged),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isOn ? Icons.power : Icons.power_off,
                  size: 16,
                  color: isOn ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  isOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOn ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SYSTEM INFORMATION
  // ============================================================

  Widget _buildSystemInformation() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dns),
                SizedBox(width: 10),
                Text(
                  'System Information',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Gateway', 'Raspberry Pi 4'),
            _buildInfoRow('IP Address', '192.168.1.60'),
            _buildInfoRow('Database', 'MariaDB'),
            _buildInfoRow('Communication', 'MQTT'),
            _buildInfoRow('API', 'PHP / Apache'),
            _buildInfoRow(
              'Zones',
              _zonesLoading ? 'Loading...' : '${_zones.length}',
            ),
            _buildInfoRow(
              'Selected Zone',
              _selectedZoneId == null ? 'All Zones' : 'Zone $_selectedZoneId',
            ),
            _buildInfoRow('SSE', _sseConnected ? 'Connected' : 'Disconnected'),
            _buildInfoRow('Connection', _sseConnected ? 'Online' : 'Offline'),
            if (_lastUpdate != null)
              _buildInfoRow(
                'Last Sensor Update',
                _formatLastUpdate(_lastUpdate!),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LAST UPDATE FORMATTER
  // ============================================================

  String _formatLastUpdate(DateTime dateTime) {
    final String hour = dateTime.hour.toString().padLeft(2, '0');

    final String minute = dateTime.minute.toString().padLeft(2, '0');

    final String second = dateTime.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  // ============================================================
  // INFORMATION ROW
  // ============================================================

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
