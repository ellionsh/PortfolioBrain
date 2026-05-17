// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/info_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double totalAssets = 0;
  double futureCF = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  Future<void> loadSummary() async {
    final data = await Api.getJson("/summary");
    setState(() {
      totalAssets = data["total_assets"] ?? 0;
      futureCF = data["future_6m_cf"] ?? 0;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text("资产总览", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: InfoCard(label: "总资产估值", value: "¥ ${totalAssets.toStringAsFixed(0)}")),
                    const SizedBox(width: 12),
                    Expanded(child: InfoCard(label: "未来 6 个月净现金流", value: "¥ ${futureCF.toStringAsFixed(0)}")),
                  ],
                ),
              ],
            ),
          );
  }
}
