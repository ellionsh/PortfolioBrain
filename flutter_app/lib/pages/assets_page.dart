import 'package:flutter/material.dart';
import '../api/api_client.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  late Future<_AssetsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AssetsData> _load() async {
    final accounts = await ApiClient.getAccounts();
    final deposits = await ApiClient.getBankDeposits();

    // 构建 account_id → account_name 映射
    final Map<int, String> accountNames = {};
    for (final row in accounts) {
      final m = row as Map<String, dynamic>;
      final id = (m['id'] as num).toInt();
      final name = m['name'] as String? ?? '未命名账户';
      accountNames[id] = name;
    }

    return _AssetsData(
      deposits: deposits,
      accountNames: accountNames,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_AssetsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          return _buildList(data);
        },
      ),
    );
  }

  Widget _buildList(_AssetsData d) {
    // 按账户名称分组
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final row in d.deposits) {
      final m = row as Map<String, dynamic>;
      final id = (m['account_id'] as num?)?.toInt();
      final name = d.accountNames[id] ?? '未知账户';

      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(m);
    }

    final accountNames = grouped.keys.toList()..sort();

    return ListView(
      children: accountNames.map((name) {
        final items = grouped[name]!;
        return ExpansionTile(
          title: Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          children: items.map((m) {
            final principal = (m['principal'] as num?)?.toDouble() ?? 0;
            final rate = (m['interest_rate'] as num?)?.toDouble() ?? 0;
            final type = m['deposit_type'] ?? '';
            final start = m['start_date'] ?? '';
            final end = m['end_date'] ?? '';

            return ListTile(
              title: Text('$type · 本金 ¥${principal.toStringAsFixed(2)}'),
              subtitle: Text('利率 ${rate * 100}%\n$start ~ $end'),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _AssetsData {
  final List<dynamic> deposits;
  final Map<int, String> accountNames;

  _AssetsData({
    required this.deposits,
    required this.accountNames,
  });
}
