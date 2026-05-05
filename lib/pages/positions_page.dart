// lib/pages/positions_page.dart
import 'package:flutter/material.dart';
import '../services/api.dart';

class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key});

  @override
  State<PositionsPage> createState() => _PositionsPageState();
}

class _PositionsPageState extends State<PositionsPage> {
  List positions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadPositions();
  }

  Future<void> loadPositions() async {
    final data = await Api.getJson("/positions");
    setState(() {
      positions = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: positions.length,
            itemBuilder: (context, i) {
              final p = positions[i];
              return ListTile(
                title: Text("${p['asset_code']}  (${p['currency']})"),
                subtitle: Text("市值：${p['market_value']}  份额：${p['shares']}"),
              );
            },
          );
  }
}
