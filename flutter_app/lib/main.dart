import 'package:flutter/material.dart';
import 'views/welcome_view.dart';

void main() {
  runApp(const SmartFarmApp());
}

class SmartFarmApp extends StatelessWidget {
  const SmartFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Farm Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey.shade100,
        fontFamily: 'Roboto', // หรือฟอนต์หลักของคุณ
      ),
      home: const WelcomeView(),
    );
  }
}