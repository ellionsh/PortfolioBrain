// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/positions_page.dart';
import 'pages/cashflow_page.dart';
import 'pages/products_page.dart';
import 'pages/chat_page.dart';

void main() {
  runApp(const PortfolioBrainApp());
}

class PortfolioBrainApp extends StatefulWidget {
  const PortfolioBrainApp({super.key});

  @override
  State<PortfolioBrainApp> createState() => _PortfolioBrainAppState();
}

class _PortfolioBrainAppState extends State<PortfolioBrainApp> {
  int index = 0;

  final pages = const [
    HomePage(),
    PositionsPage(),
    CashflowPage(),
    ProductsPage(),
    ChatPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PortfolioBrain",
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
      ),
      home: Scaffold(
        body: pages[index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => setState(() => index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "首页"),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: "持仓"),
            BottomNavigationBarItem(icon: Icon(Icons.timeline), label: "现金流"),
            BottomNavigationBarItem(icon: Icon(Icons.list), label: "理财"),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: "AI"),
          ],
        ),
      ),
    );
  }
}
