import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsChartWidget extends StatelessWidget {
  const AnalyticsChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'แนวโน้มความชื้นในดิน (24 ชม. ล่าสุด)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Zone 01',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
  gridData: FlGridData(
    show: true,
    drawVerticalLine: false,

    getDrawingHorizontalLine: (value) {
      return FlLine(
        color: Colors.grey.shade200,
        strokeWidth: 1,
      );
    },
  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          String text = '';
                          switch (value.toInt()) {
                            case 0: text = '00:00'; break;
                            case 4: text = '04:00'; break;
                            case 8: text = '08:00'; break;
                            case 12: text = '12:00'; break;
                            case 16: text = '16:00'; break;
                            case 20: text = '20:00'; break;
                          }
                          return Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%', style: TextStyle(color: Colors.grey.shade500, fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 20,
                  minY: 10,
                  maxY: 60,
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 35),
                        FlSpot(4, 32),
                        FlSpot(8, 28),
                        FlSpot(12, 45), // ตอนรดน้ำความชื้นจะพุ่งขึ้น
                        FlSpot(16, 40),
                        FlSpot(20, 32),
                      ],
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withValues(alpha:0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}