import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/accounts_page.dart';
import 'pages/deposits_page.dart';
import 'pages/cashflow_page.dart';
import 'pages/insurance_page.dart';
import 'pages/financial_products_page.dart';
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
    DepositsPage(),
    InsurancePage(),
    FinancialProductsPage(),
    CashflowPage(),
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
            BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: '账户'),
            BottomNavigationBarItem(icon: Icon(Icons.savings), label: '存款'),
            BottomNavigationBarItem(icon: Icon(Icons.health_and_safety), label: '保险'),
            BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: '理财'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '现金流'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: '助手'),
          ],
        ),
      ),
    );
  }
}

