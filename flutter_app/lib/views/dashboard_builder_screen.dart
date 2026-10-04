import 'dart:async';

import 'package:flutter/material.dart';

import 'soil_test_screen.dart';

import '../services/api_service.dart';
import '../services/sse_service.dart';

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

  /// Error จาก Zone API
  String? _zonesError;

  // ============================================================
  // REAL-TIME SENSOR STATE
  // ============================================================

  /// เก็บค่าตามโครงสร้าง:
  ///
  /// zone_id
  ///   └── sensor_code
  ///         └── value
  ///
  /// ตัวอย่าง:
  ///
  /// {
  ///   1: {
  ///     'temperature_01': 22.6,
  ///     'humidity_01': 44.0,
  ///     'soil_moisture_01': 24.0,
  ///   }
  /// }
  final Map<int, Map<String, double>> _sensorValuesByZone = {};

  // ============================================================
  // SSE CONNECTION STATE
  // ============================================================

  /// สถานะการเชื่อมต่อ SSE
  bool _sseConnected = false;

  /// เก็บ subscription เพื่อยกเลิกเมื่อออกจากหน้า
  StreamSubscription<Map<String, dynamic>>? _sseSubscription;

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

    /// เชื่อมต่อ SSE
    _connectSse();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _sseSubscription = null;

    super.dispose();
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

  Future<void> _loadLatestSoilTests() async {
    final Map<int, dynamic> latestByZone = {};

    for (final zone in _zones) {
      final int? zoneId = int.tryParse(zone['id'].toString());
      if (zoneId == null) continue;

      try {
        final List<dynamic> history =
            await ApiService.getSoilTestHistory(zoneId);

        if (history.isNotEmpty) {
          latestByZone[zoneId] = history.first;
        }
      } catch (_) {
        // Keep dashboard usable if soil-test history is unavailable.
      }
    }

    if (!mounted) return;

    setState(() {
      _latestSoilTestByZone = latestByZone;
    });
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

    _sseSubscription = sseService.connectToRealtimeStream().listen(
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
      },
      onDone: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _sseConnected = false;
        });
      },
      cancelOnError: false,
    );
  }

  // ============================================================
  // SSE DATA HANDLER
  // ============================================================

  void _handleSseData(Map<String, dynamic> data) {
    // ----------------------------------------------------------
    // SSE CONNECTION EVENT
    // ----------------------------------------------------------

    if (data['status'] == 'connected') {
      if (!mounted) {
        return;
      }

      setState(() {
        _sseConnected = true;
      });

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

    /// Backend ส่ง value เป็น String เช่น:
    ///
    /// "31.5000"
    ///
    /// จึงต้อง parse เป็น double
    final double? value = double.tryParse(rawValue.toString());

    /// ถ้าแปลงค่าไม่ได้ ไม่เปลี่ยน State
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

      _lastUpdate = DateTime.now();
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
    //
    // ถ้าเลือก All Zones:
    // ค้นหาค่าจาก Zone ที่มีข้อมูล
    //
    // ถ้ามีหลาย Zone ที่ใช้ sensor_code เดียวกัน
    // จะคืนค่าจาก Zone แรกที่มีข้อมูล
    //
    // PHASE 10.5 ยังไม่ได้ทำ aggregate
    // ----------------------------------------------------------

    for (final Map<String, double> zoneSensors in _sensorValuesByZone.values) {
      final double? value = zoneSensors[sensorCode];

      if (value != null) {
        return value;
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
        title: const Text(
          'Smart Farm Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              _loadZones();
              _connectSse();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Soil Test',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SoilTestScreen(),
                ),
              );
            },
            icon: const Icon(Icons.science),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: const Icon(Icons.settings),
          ),
          const SizedBox(width: 8),
        ],
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
            _sseConnected ? 'Gateway Online' : 'Gateway Offline',
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

            // --------------------------------------------------
            // LOADING
            // --------------------------------------------------
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
            // --------------------------------------------------
            // ERROR
            // --------------------------------------------------
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
            // --------------------------------------------------
            // ZONE LIST
            // --------------------------------------------------
            else
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,

                  /// +1 สำหรับ All Zones
                  itemCount: _zones.length + 1,

                  separatorBuilder: (_, _) => const SizedBox(width: 8),

                  itemBuilder: (context, index) {
                    // ----------------------------------------
                    // ALL ZONES
                    // ----------------------------------------

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

                    // ----------------------------------------
                    // API ZONE
                    // ----------------------------------------

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

            // --------------------------------------------------
            // SELECTED ZONE INFORMATION
            // --------------------------------------------------
            if (!_zonesLoading &&
                _zonesError == null &&
                _selectedZoneId != null) ...[
              const SizedBox(height: 10),
              Text(
                _getSelectedZoneDescription(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
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

    // ----------------------------------------------------------
    // GET CURRENT ZONE SENSOR VALUES
    // ----------------------------------------------------------

    final double? temperature = _getSensorValue('temperature_01');

    final double? humidity = _getSensorValue('humidity_01');

    final double? soilMoisture = _getSensorValue('soil_moisture_01');

    final dynamic latestSoilTest = _selectedZoneId != null
        ? _latestSoilTestByZone[_selectedZoneId]
        : (_latestSoilTestByZone.values.isNotEmpty
            ? _latestSoilTestByZone.values.reduce((a, b) {
                final DateTime dateA =
                    DateTime.tryParse(
                          a['measured_at']?.toString() ?? '',
                        ) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                final DateTime dateB =
                    DateTime.tryParse(
                          b['measured_at']?.toString() ?? '',
                        ) ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                return dateA.isAfter(dateB) ? a : b;
              })
            : null);

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
      // ยังไม่คำนวณ VPD ใน PHASE 10.5
      // --------------------------------------------------------
      _buildSensorCard(
        title: 'VPD',
        value: '--',
        unit: 'kPa',
        icon: Icons.air,
        status: 'Pending',
      ),

      // --------------------------------------------------------
      // pH — LATEST SOIL TEST
      // --------------------------------------------------------
      _buildSensorCard(
        title: 'pH',
        value: latestSoilTest?['ph']?.toString() ?? '--',
        unit: '',
        icon: Icons.science,
        status: latestSoilTest != null ? 'Latest' : 'Pending',
      ),

      // --------------------------------------------------------
      // NPK — LATEST SOIL TEST
      // --------------------------------------------------------
      _buildSensorCard(
        title: 'NPK',
        value: latestSoilTest != null
            ? 'N ${latestSoilTest['nitrogen'] ?? '-'} | '
                'P ${latestSoilTest['phosphorus'] ?? '-'} | '
                'K ${latestSoilTest['potassium'] ?? '-'}'
            : '--',
        unit: 'mg/kg',
        icon: Icons.eco,
        status: latestSoilTest != null ? 'Latest' : 'Pending',
      ),

      // --------------------------------------------------------
      // WATER PUMP
      // --------------------------------------------------------
      // Actuator ยังเป็น UI simulation
      // --------------------------------------------------------
      _buildActuatorCard(
        title: 'Water Pump',
        subtitle: 'Main irrigation pump',
        icon: Icons.water,
        isOn: false,
      ),

      // --------------------------------------------------------
      // OXYGEN PUMP
      // --------------------------------------------------------
      // Actuator ยังเป็น UI simulation
      // --------------------------------------------------------
      _buildActuatorCard(
        title: 'Oxygen Pump',
        subtitle: 'Fish pond oxygen',
        icon: Icons.bubble_chart,
        isOn: true,
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
          mainAxisExtent: 190,
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
            const Spacer(),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
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
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
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
                Switch(
                  value: isOn,
                  onChanged: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$title ${value ? "ON" : "OFF"}')),
                    );
                  },
                ),
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
