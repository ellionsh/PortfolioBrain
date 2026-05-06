import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/accounts_page.dart';
import 'pages/assets_page.dart';
import 'pages/cashflow_page.dart';
import 'pages/insurance_page.dart';
import 'pages/agent_chat_page.dart';

void main() {
  runApp(const PortfolioBrainApp());
}

class PortfolioBrainApp extends StatefulWidget {
  const PortfolioBrainApp({super.key});

  @override
  State<PortfolioBrainApp> createState() => _PortfolioBrainAppState();
}

class _PortfolioBrainAppState extends State<PortfolioBrainApp> {
  int _index = 0;

  final _pages = const [
    HomePage(),
    AccountsPage(),
    AssetsPage(),
    CashflowPage(),
    InsurancePage(),
    AgentChatPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PortfolioBrain',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: _pages[_index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '首页'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: '账户'),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: '资产'),
            BottomNavigationBarItem(icon: Icon(Icons.timeline), label: '现金流'),
            BottomNavigationBarItem(icon: Icon(Icons.shield), label: '保险'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: '助手'),
          ],
        ),
      ),
    );
  }
}

