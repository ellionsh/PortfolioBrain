// lib/pages/cashflow_page.dart
import 'package:flutter/material.dart';
import '../services/api.dart';

class CashflowPage extends StatefulWidget {
  const CashflowPage({super.key});

  @override
  State<CashflowPage> createState() => _CashflowPageState();
}

class _CashflowPageState extends State<CashflowPage> {
  List cashflows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCF();
  }

  Future<void> loadCF() async {
    final data = await Api.getJson("/cashflows");
    setState(() {
      cashflows = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: cashflows.length,
            itemBuilder: (context, i) {
              final c = cashflows[i];
              return ListTile(
                title: Text("${c['date']}  ${c['amount']}"),
                subtitle: Text("${c['description']}"),
                trailing: Text(c['direction'] == "inflow" ? "收入" : "支出"),
              );
            },
          );
  }
}
