import 'package:flutter/material.dart';
import 'login_view.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isThai = true; // สลับภาษาไทย / อังกฤษ
  final _isGatewayConnected = true; // สถานะจำลองการเชื่อมต่อ Gateway

  // ข้อมูลฟีเจอร์แนะนำ (รองรับ 2 ภาษา)
  final List<Map<String, String>> _features = [
    {
      'title_th': 'ระบบควบคุมและรดน้ำอัจฉริยะ',
      'title_en': 'Smart Auto Watering',
      'desc_th': 'ตั้งค่าเงื่อนไขความชื้นในดินและเวลาทำงานอัตโนมัติ ป้องกันความเสียหายและประหยัดน้ำ',
      'desc_en': 'Automate irrigation based on soil moisture and schedule to save water and protect crops.',
      'icon': 'water_drop',
    },
    {
      'title_th': 'แจ้งเตือนภัยผ่าน Telegram',
      'title_en': 'Telegram Alerts',
      'desc_th': 'รับข้อความแจ้งเตือนฉุกเฉินทันทีเมื่อเซนเซอร์ผิดปกติหรือระบบทำงานอัตโนมัติ',
      'desc_en': 'Receive instant emergency alerts when sensors trigger thresholds or automation runs.',
      'icon': 'notifications_active',
    },
    {
      'title_th': 'กราฟวิเคราะห์ข้อมูลย้อนหลัง',
      'title_en': 'Analytics Charts',
      'desc_th': 'ดูแนวโน้มอุณหภูมิและความชื้นย้อนหลัง 24 ชั่วโมง เพื่อการบริหารจัดการฟาร์มที่แม่นยำ',
      'desc_en': 'Analyze 24-hour historical trends for precise farm management and planning.',
      'icon': 'analytics',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // ส่วนบน: Gateway Status และ ปุ่มสลับภาษา
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gateway Status Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isGatewayConnected ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isGatewayConnected ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: _isGatewayConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isGatewayConnected 
                              ? (_isThai ? 'เชื่อมต่อ Gateway แล้ว' : 'Gateway Connected') 
                              : (_isThai ? 'ไม่พบ Gateway' : 'Gateway Offline'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isGatewayConnected ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Language Selector
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isThai = !_isThai;
                      });
                    },
                    icon: const Icon(Icons.language, size: 18, color: Colors.grey),
                    label: Text(
                      _isThai ? 'EN' : 'TH',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // โลโก้แบรนด์
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.eco_rounded,
                  size: 50,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Smart Farm Platform',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              // ส่วนกลาง: PageView แสดง Feature Highlights แบบสไลด์
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _features.length,
                        itemBuilder: (context, index) {
                          final feature = _features[index];
                          IconData iconData;
                          if (feature['icon'] == 'water_drop') {
                            iconData = Icons.water_drop_outlined;
                          } else if (feature['icon'] == 'notifications_active') {
                            iconData = Icons.notifications_active_outlined;
                          } else {
                            iconData = Icons.insights_outlined;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100.withValues(alpha:0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData, size: 60, color: Colors.green.shade800),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _isThai ? feature['th'] ?? '' : feature['en'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _isThai ? feature['th'] ?? '' : feature['en'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Dot Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _features.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? Colors.green.shade700 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ปุ่มเริ่มต้นใช้งาน
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginView()),
                    );
                  },
                  child: Text(
                    _isThai ? 'เริ่มต้นใช้งาน' : 'Get Started',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}