import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/api_service.dart';

class ActuatorHistoryScreen extends StatefulWidget {
  final String actuatorId;
  final String actuatorName;

  const ActuatorHistoryScreen({
    super.key,
    required this.actuatorId,
    required this.actuatorName,
  });

  @override
  State<ActuatorHistoryScreen> createState() => _ActuatorHistoryScreenState();
}

class _ActuatorHistoryScreenState extends State<ActuatorHistoryScreen> {
  static const List<Map<String, String>> _availableActuators = [
    {'id': 'water_pump_01', 'name': 'Water Pump'},
    {'id': 'oxygen_pump_01', 'name': 'Oxygen Pump'},
  ];

  late String _selectedActuatorId;
  late String _selectedActuatorName;

  List<dynamic> _history = [];
  bool _loading = true;
  String? _error;
  String _stateFilter = 'all';
  String _periodFilter = 'all';

  @override
  void initState() {
    super.initState();

    _selectedActuatorId = widget.actuatorId;
    _selectedActuatorName = widget.actuatorName;

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final history = await ApiService.getActuatorHistory(_selectedActuatorId);

      if (!mounted) {
        return;
      }

      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectActuator(String actuatorId) async {
    final actuator = _availableActuators.firstWhere(
      (item) => item['id'] == actuatorId,
    );

    setState(() {
      _selectedActuatorId = actuator['id']!;
      _selectedActuatorName = actuator['name']!;
    });

    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_selectedActuatorName History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildActuatorSelector(),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(child: _buildStateFilter()),
                const SizedBox(width: 12),
                Expanded(child: _buildPeriodFilter()),
              ],
            ),
          ),
          _buildEventCount(),
          _buildHistorySummary(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildActuatorSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedActuatorId,
        decoration: const InputDecoration(
          labelText: 'Actuator',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.settings_remote),
        ),
        items: _availableActuators.map((actuator) {
          return DropdownMenuItem<String>(
            value: actuator['id'],
            child: Text(actuator['name']!),
          );
        }).toList(),
        onChanged: _loading
            ? null
            : (value) {
                if (value != null && value != _selectedActuatorId) {
                  _selectActuator(value);
                }
              },
      ),
    );
  }

  Widget _buildStateFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _stateFilter,
      decoration: const InputDecoration(
        labelText: 'State',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.power),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('ALL')),
        DropdownMenuItem(value: 'on', child: Text('ON')),
        DropdownMenuItem(value: 'off', child: Text('OFF')),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _stateFilter = value;
        });
      },
    );
  }

  Widget _buildPeriodFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _periodFilter,
      decoration: const InputDecoration(
        labelText: 'Period',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.date_range),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('ALL')),
        DropdownMenuItem(value: 'today', child: Text('TODAY')),
        DropdownMenuItem(value: '7d', child: Text('7 DAYS')),
        DropdownMenuItem(value: '30d', child: Text('30 DAYS')),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _periodFilter = value;
        });
      },
    );
  }

  List<dynamic> get _filteredHistory {
    final now = DateTime.now();

    return _history.where((item) {
      final state = item['actual_state']?.toString().toLowerCase() ?? 'unknown';

      // State filter
      if (_stateFilter != 'all' && state != _stateFilter) {
        return false;
      }

      // Period filter
      if (_periodFilter != 'all') {
        final changedAt = item['changed_at']?.toString();

        if (changedAt == null) {
          return false;
        }

        final parsedDate = DateTime.tryParse(changedAt.replaceFirst(' ', 'T'));

        if (parsedDate == null) {
          return false;
        }

        final difference = now.difference(parsedDate);

        if (_periodFilter == 'today') {
          final today = DateTime(now.year, now.month, now.day);

          if (parsedDate.isBefore(today)) {
            return false;
          }
        }

        if (_periodFilter == '7d' && difference > const Duration(days: 7)) {
          return false;
        }

        if (_periodFilter == '30d' && difference > const Duration(days: 30)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildEventCount() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Showing ${_filteredHistory.length} events',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Duration _calculateOnDuration() {
    final history = _filteredHistory.reversed.toList();

    if (history.length < 2) {
      return Duration.zero;
    }

    Duration total = Duration.zero;

    for (int i = 0; i < history.length - 1; i++) {
      final current = history[i];
      final next = history[i + 1];

      final currentState = current['actual_state']?.toString().toLowerCase();

      if (currentState != 'on') {
        continue;
      }

      final currentChangedAt = current['changed_at']?.toString();

      final nextChangedAt = next['changed_at']?.toString();

      if (currentChangedAt == null || nextChangedAt == null) {
        continue;
      }

      final currentTime = DateTime.tryParse(
        currentChangedAt.replaceFirst(' ', 'T'),
      );

      final nextTime = DateTime.tryParse(nextChangedAt.replaceFirst(' ', 'T'));

      if (currentTime == null || nextTime == null) {
        continue;
      }

      if (nextTime.isAfter(currentTime)) {
        total += nextTime.difference(currentTime);
      }
    }

    return total;
  }

  Widget _buildHistorySummary() {
    final total = _filteredHistory.length;

    final onCount = _filteredHistory.where((item) {
      return item['actual_state']?.toString().toLowerCase() == 'on';
    }).length;

    final offCount = _filteredHistory.where((item) {
      return item['actual_state']?.toString().toLowerCase() == 'off';
    }).length;

    final lastState = _filteredHistory.isNotEmpty
        ? _filteredHistory.first['actual_state']?.toString().toUpperCase() ??
              'UNKNOWN'
        : '-';
    final onDuration = _calculateOnDuration();

    final onDurationText = [
      if (onDuration.inHours > 0) '${onDuration.inHours}h',
      '${onDuration.inMinutes.remainder(60)}m',
      '${onDuration.inSeconds.remainder(60)}s',
    ].join(' ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Total Events', total.toString()),
              ),
              Expanded(
                child: _buildSummaryItem('ON Events', onCount.toString()),
              ),
              Expanded(
                child: _buildSummaryItem('OFF Events', offCount.toString()),
              ),
              Expanded(child: _buildSummaryItem('Last State', lastState)),
              Expanded(child: _buildSummaryItem('ON Duration', onDurationText)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStateTimeline() {
    final history = _filteredHistory.reversed.toList();

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = <FlSpot>[];

    for (int i = 0; i < history.length; i++) {
      final state =
          history[i]['actual_state']?.toString().toLowerCase() ?? 'unknown';

      spots.add(FlSpot(i.toDouble(), state == 'on' ? 1 : 0));
    }

    final maxX = history.length > 1 ? (history.length - 1).toDouble() : 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'State Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: maxX,
                    minY: -0.1,
                    maxY: 1.1,
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value == 1) {
                              return const Text('ON');
                            }

                            if (value == 0) {
                              return const Text('OFF');
                            }

                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return const Center(child: Text('No history available'));
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStateTimeline(),
          const SizedBox(height: 8),
          ..._filteredHistory.map((item) {
            final state = item['actual_state']?.toString() ?? 'unknown';

            final changedAt = item['changed_at']?.toString() ?? '-';

            final source = item['source']?.toString() ?? '-';

            final deviceHealth = item['device_health']?.toString() ?? '-';

            final isOn = state == 'on';

            return Card(
              child: ListTile(
                leading: Icon(isOn ? Icons.power : Icons.power_off),
                title: Text(
                  state.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$changedAt\n'
                  'Source: $source\n'
                  'Device Health: $deviceHealth',
                ),
                isThreeLine: false,
              ),
            );
          }),
        ],
      ),
    );
  }
}
