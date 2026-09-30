import 'package:flutter/material.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedZone = 0;

  final List<String> _zones = [
    'All Zones',
    'Zone 1',
    'Zone 2',
    'Zone 3',
    'Zone 4',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Smart Farm Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
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
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                  ),
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'IoT Agriculture Monitoring & Control',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
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

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Gateway Online',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _zones.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final bool selected = _selectedZone == index;

                  return ChoiceChip(
                    label: Text(_zones[index]),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedZone = index;
                      });
                    },
                    selectedColor: Colors.green.shade600,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Normal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'All connected devices are operating normally.',
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

    final List<Widget> cards = [
      _buildSensorCard(
        title: 'Temperature',
        value: '28.5',
        unit: '°C',
        icon: Icons.thermostat,
        status: 'Normal',
      ),
      _buildSensorCard(
        title: 'Humidity',
        value: '72',
        unit: '%',
        icon: Icons.water_drop,
        status: 'Normal',
      ),
      _buildSensorCard(
        title: 'Soil Moisture',
        value: '32',
        unit: '%',
        icon: Icons.grass,
        status: 'Normal',
      ),
      _buildSensorCard(
        title: 'VPD',
        value: '1.0',
        unit: 'kPa',
        icon: Icons.air,
        status: 'Optimal',
      ),
      _buildSensorCard(
        title: 'pH',
        value: '6.5',
        unit: '',
        icon: Icons.science,
        status: 'Normal',
      ),
      _buildSensorCard(
        title: 'NPK',
        value: '245',
        unit: 'ppm',
        icon: Icons.eco,
        status: 'Normal',
      ),
      _buildActuatorCard(
        title: 'Water Pump',
        subtitle: 'Main irrigation pump',
        icon: Icons.water,
        isOn: false,
      ),
      _buildActuatorCard(
        title: 'Oxygen Pump',
        subtitle: 'Fish pond oxygen',
        icon: Icons.bubble_chart,
        isOn: true,
      ),
    ];

    /*
     * สำคัญ:
     *
     * GridView ไม่ควรอยู่ในพื้นที่ที่ width เป็น unbounded
     * เราจึงกำหนด width จาก availableWidth โดยตรง
     * และใช้ shrinkWrap + NeverScrollableScrollPhysics
     * เพราะ SingleChildScrollView ด้านนอกเป็นตัวเลื่อนหลัก
     */
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

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required String status,
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
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
                    color: isOn
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isOn
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isOn,
                  onChanged: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$title ${value ? "ON" : "OFF"}',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isOn
                      ? Icons.power
                      : Icons.power_off,
                  size: 16,
                  color: isOn
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  isOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOn
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'Gateway',
              'Raspberry Pi 4',
            ),
            _buildInfoRow(
              'IP Address',
              '192.168.1.60',
            ),
            _buildInfoRow(
              'Database',
              'MariaDB',
            ),
            _buildInfoRow(
              'Communication',
              'MQTT',
            ),
            _buildInfoRow(
              'API',
              'PHP / Apache',
            ),
            _buildInfoRow(
              'Connection',
              'Online',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}