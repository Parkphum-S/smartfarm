import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class SoilTestScreen extends StatefulWidget {
  const SoilTestScreen({super.key});

  @override
  State<SoilTestScreen> createState() => _SoilTestScreenState();
}

class _SoilTestScreenState extends State<SoilTestScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _phController = TextEditingController();

  final TextEditingController _nitrogenController = TextEditingController();

  final TextEditingController _phosphorusController = TextEditingController();

  final TextEditingController _potassiumController = TextEditingController();

  final TextEditingController _noteController = TextEditingController();

  List<dynamic> _zones = [];
  int? _selectedZoneId;

  bool _loadingZones = true;
  bool _saving = false;

  List<dynamic> _soilTestHistory = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _phController.dispose();
    _nitrogenController.dispose();
    _phosphorusController.dispose();
    _potassiumController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSoilTestHistory() async {
    if (_selectedZoneId == null) {
      return;
    }

    setState(() {
      _loadingHistory = true;
    });

    try {
      final List<dynamic> history = await ApiService.getSoilTestHistory(
        _selectedZoneId!,
      );

      if (!mounted) return;

      setState(() {
        _soilTestHistory = history;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingHistory = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโหลดประวัติผลตรวจดิน: $e')),
      );
    }
  }

  Future<void> _loadZones() async {
    try {
      final List<dynamic> zones = await ApiService.getZones();

      if (!mounted) return;

      int? firstZoneId;

      if (zones.isNotEmpty) {
        firstZoneId = int.tryParse(zones.first['id'].toString());
      }

      setState(() {
        _zones = zones;
        _loadingZones = false;
        _selectedZoneId = firstZoneId;
      });

      if (firstZoneId != null) {
        await _loadSoilTestHistory();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingZones = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ไม่สามารถโหลด Zone ได้: $e')));
    }
  }

  Future<void> _saveSoilTest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedZoneId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือก Zone')));
      return;
    }

    setState(() {
      _saving = true;
    });

    final bool success = await ApiService.createSoilTest(
      zoneId: _selectedZoneId!,
      ph: double.parse(_phController.text.trim()),
      nitrogen: double.parse(_nitrogenController.text.trim()),
      phosphorus: double.parse(_phosphorusController.text.trim()),
      potassium: double.parse(_potassiumController.text.trim()),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    if (success) {
      _clearForm();

      await _loadSoilTestHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกผลตรวจดินเรียบร้อยแล้ว')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถบันทึกผลตรวจดินได้')),
      );
    }
  }

  void _clearForm() {
    _phController.clear();
    _nitrogenController.clear();
    _phosphorusController.clear();
    _potassiumController.clear();
    _noteController.clear();
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอก$fieldName';
    }

    if (double.tryParse(value.trim()) == null) {
      return '$fieldName ต้องเป็นตัวเลข';
    }

    return null;
  }

  String? _validateNonNegativeNumber(
    String? value,
    String fieldName,
  ) {
    final String? error = _validateNumber(value, fieldName);

    if (error != null) {
      return error;
    }

    final double number = double.parse(value!.trim());

    if (number < 0) {
      return '$fieldName ต้องไม่ติดลบ';
    }

    return null;
  }

  String? _validatePh(String? value) {
    final String? error = _validateNumber(value, 'ค่า pH');

    if (error != null) {
      return error;
    }

    final double ph = double.parse(value!.trim());

    if (ph < 0 || ph > 14) {
      return 'ค่า pH ต้องอยู่ระหว่าง 0 - 14';
    }

    return null;
  }

  InputDecoration _inputDecoration(String label, String unit) {
    return InputDecoration(
      labelText: label,
      suffixText: unit,
      border: const OutlineInputBorder(),
    );
  }

  String _formatMeasuredAt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    try {
      final DateTime dateTime =
          DateTime.parse(value.toString());

      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (_) {
      return value.toString();
    }
  }

  String _getZoneName(int? zoneId) {
    if (zoneId == null) {
      return 'ไม่ระบุ Zone';
    }

    for (final zone in _zones) {
      final int? id = int.tryParse(zone['id'].toString());

      if (id == zoneId) {
        return zone['name']?.toString() ??
            zone['code']?.toString() ??
            'Zone $zoneId';
      }
    }

    return 'Zone $zoneId';
  }

  Widget _buildSoilValueRow(String label, dynamic value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${value ?? '-'} $unit'.trim(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestSoilTest() {
    if (_loadingHistory) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_soilTestHistory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('ยังไม่มีผลตรวจดิน')),
        ),
      );
    }

    final dynamic latest = _soilTestHistory.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Text(
                  'ผลตรวจล่าสุด',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildSoilValueRow('pH', latest['ph'], ''),

            _buildSoilValueRow('Nitrogen (N)', latest['nitrogen'], 'mg/kg'),

            _buildSoilValueRow('Phosphorus (P)', latest['phosphorus'], 'mg/kg'),

            _buildSoilValueRow('Potassium (K)', latest['potassium'], 'mg/kg'),

            const Divider(),

            Text(
              'ตรวจเมื่อ: '
              '${_formatMeasuredAt(latest['measured_at'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilTestHistoryList() {
    if (_loadingHistory) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_soilTestHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 28),
                const SizedBox(width: 10),
                Text(
                  'ประวัติผลตรวจดิน',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._soilTestHistory.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.science),
                        ),
                        title: Text(
                          'pH ${item['ph'] ?? '-'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'N: ${item['nitrogen'] ?? '-'} mg/kg\n'
                            'P: ${item['phosphorus'] ?? '-'} mg/kg\n'
                            'K: ${item['potassium'] ?? '-'} mg/kg',
                          ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _getZoneName(
                                int.tryParse(
                                  item['zone_id'].toString(),
                                ),
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatMeasuredAt(item['measured_at']),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                        ],
                      ),
                      if (item['note'] != null &&
                          item['note'].toString().trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.notes,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item['note'].toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ผลตรวจดิน')),
      body: _loadingZones
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.science,
                                  color: Colors.green,
                                  size: 30,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'บันทึกผลตรวจดิน',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            DropdownButtonFormField<int>(
                              initialValue: _selectedZoneId,
                              decoration: const InputDecoration(
                                labelText: 'Zone',
                                border: OutlineInputBorder(),
                              ),
                              items: _zones
                                  .map(
                                    (zone) => DropdownMenuItem<int>(
                                      value: int.tryParse(
                                        zone['id'].toString(),
                                      ),
                                      child: Text(
                                        zone['name']?.toString() ??
                                            zone['code']?.toString() ??
                                            'Zone',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedZoneId = value;
                                      });
                                    },
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _phController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration('pH', ''),
                              validator: _validatePh,
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _nitrogenController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                'Nitrogen (N)',
                                'mg/kg',
                              ),
                              validator: (value) =>
                                  _validateNonNegativeNumber(value, 'ค่า Nitrogen'),
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _phosphorusController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                'Phosphorus (P)',
                                'mg/kg',
                              ),
                              validator: (value) =>
                                  _validateNonNegativeNumber(value, 'ค่า Phosphorus'),
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _potassiumController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                'Potassium (K)',
                                'mg/kg',
                              ),
                              validator: (value) =>
                                  _validateNonNegativeNumber(value, 'ค่า Potassium'),
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _noteController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'หมายเหตุ',
                                hintText: 'เช่น ตรวจด้วยเครื่องวัดภาคสนาม',
                                border: OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _saveSoilTest,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: Text(
                                  _saving ? 'กำลังบันทึก...' : 'บันทึกผลตรวจ',
                                ),
                              ),
                            ),
                            const Divider(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLatestSoilTest(),

                    const SizedBox(height: 16),
                    _buildSoilTestHistoryList(),
                  ],
                ),
              ),
            ),
    );
  }
}
