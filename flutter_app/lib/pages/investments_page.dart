import 'package:flutter/material.dart';

import 'deposits_page.dart';
import 'financial_products_page.dart';
import 'fund_products_page.dart';
import 'insurance_page.dart';

class InvestmentsPage extends StatelessWidget {
  const InvestmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '资产',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TabBar(
              tabs: [
                Tab(icon: Icon(Icons.savings), text: '存款'),
                Tab(icon: Icon(Icons.show_chart), text: '理财'),
                Tab(icon: Icon(Icons.health_and_safety), text: '保险'),
                Tab(icon: Icon(Icons.stacked_line_chart), text: '基金'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  DepositsPage(),
                  FinancialProductsPage(),
                  InsurancePage(),
                  FundProductsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
