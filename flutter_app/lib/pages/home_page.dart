import 'package:flutter/material.dart';
import '../api/api_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
  final summary = await ApiClient.getSummary();
  final accounts = await ApiClient.getAccounts();
  final deposits = await ApiClient.getBankDeposits();

  // account_id → account_name 映射
  final Map<int, String> accountNames = {};
  for (final row in accounts) {
    final m = row as Map<String, dynamic>;
    final id = (m['id'] as num).toInt();
    final name = m['name'] as String? ?? '未命名账户';
    accountNames[id] = name;
  }

  // 按账户聚合本金
  final Map<int, double> byAccount = {};
  for (final row in deposits) {
    final m = row as Map<String, dynamic>;
    final id = (m['account_id'] as num?)?.toInt();
    final principal = (m['principal'] as num?)?.toDouble() ?? 0;
    if (id == null) continue;
    byAccount[id] = (byAccount[id] ?? 0) + principal;
  }

  return _DashboardData(
    totalAssets: (summary['total_assets'] as num?)?.toDouble() ?? 0,
    future6mCf: (summary['future_6m_cf'] as num?)?.toDouble() ?? 0,
    assetsByAccount: byAccount,
    accountNames: accountNames,
  );
}


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text(
                  '资产总览',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSummaryCards(data),
                const SizedBox(height: 24),
                const Text(
                  '资产分布（按账户）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDistributionList(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(_DashboardData d) {
    final cfColor = d.future6mCf >= 0 ? Colors.green : Colors.red;
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('总资产',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    d.totalAssets.toStringAsFixed(2),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('未来6个月现金流',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    d.future6mCf.toStringAsFixed(2),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: cfColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
Widget _buildDistributionList(_DashboardData d) {
  if (d.assetsByAccount.isEmpty) {
    return const Text('暂无银行存款数据');
  }

  final total = d.assetsByAccount.values.fold<double>(0, (a, b) => a + b);
  final entries = d.assetsByAccount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Column(
    children: entries.map((e) {
      final accountId = e.key;
      final accountName = d.accountNames[accountId] ?? '账户 $accountId';
      final ratio = total == 0 ? 0.0 : (e.value / total).toDouble();

      return ListTile(
        leading: CircleAvatar(
          child: Text(accountName.substring(0, 1)),
        ),
        title: Text(accountName),
        subtitle: Text(
          '本金: ${e.value.toStringAsFixed(2)} · 占比 ${(ratio * 100).toStringAsFixed(1)}%',
        ),
        trailing: SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: ratio,   // ratio 已经是 double
            minHeight: 6,
          ),
        ),
      );
    }).toList(),
  );
}


}

class _DashboardData {
  final double totalAssets;
  final double future6mCf;
  final Map<int, double> assetsByAccount;
  final Map<int, String> accountNames;

  _DashboardData({
    required this.totalAssets,
    required this.future6mCf,
    required this.assetsByAccount,
    required this.accountNames,
  });
}

