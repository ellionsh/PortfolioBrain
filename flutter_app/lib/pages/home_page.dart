import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../utils/error_format.dart';

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
    final financialProducts = await ApiClient.getFinancialProducts();
    final insuranceProducts = await ApiClient.getInsurance();
    final fundProducts = await ApiClient.getFundProducts();

    final Map<int, String> accountNames = {};
    for (final row in accounts) {
      final m = row as Map<String, dynamic>;
      final id = (m['id'] as num).toInt();
      final name = m['name'] as String? ?? '未命名账户';
      accountNames[id] = name;
    }

    final Map<int, _AccountAssetBreakdown> byAccount = {};

    void addAsset(int? accountId, double amount, _AssetKind kind) {
      if (accountId == null || amount == 0) return;
      final breakdown = byAccount.putIfAbsent(
        accountId,
        () => _AccountAssetBreakdown(),
      );
      breakdown.add(kind, amount);
    }

    for (final row in deposits) {
      final m = row as Map<String, dynamic>;
      addAsset(
        (m['account_id'] as num?)?.toInt(),
        (m['principal'] as num?)?.toDouble() ?? 0,
        _AssetKind.deposit,
      );
    }

    for (final row in financialProducts) {
      final m = row as Map<String, dynamic>;
      final principal = (m['principal'] as num?)?.toDouble() ?? 0;
      final shares = (m['shares'] as num?)?.toDouble() ?? 0;
      final nav = (m['nav'] as num?)?.toDouble();
      final amount = nav == null ? principal : shares * nav;
      addAsset(
        (m['account_id'] as num?)?.toInt(),
        amount,
        _AssetKind.financial,
      );
    }

    for (final row in insuranceProducts) {
      final m = row as Map<String, dynamic>;
      final cashValue = (m['cash_value'] as num?)?.toDouble();
      final premium = (m['premium'] as num?)?.toDouble() ?? 0;
      addAsset(
        (m['account_id'] as num?)?.toInt(),
        cashValue ?? premium,
        _AssetKind.insurance,
      );
    }

    for (final row in fundProducts) {
      final m = row as Map<String, dynamic>;
      final principal = (m['principal'] as num?)?.toDouble() ?? 0;
      final shares = (m['shares'] as num?)?.toDouble() ?? 0;
      final nav = (m['nav'] as num?)?.toDouble();
      final amount = nav == null ? principal : shares * nav;
      addAsset(
        (m['account_id'] as num?)?.toInt(),
        amount,
        _AssetKind.fund,
      );
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
            return Center(child: Text('加载失败: ${formatApiError(snapshot.error!)}'));
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
      return const Text('暂无资产数据');
    }

    final total = d.assetsByAccount.values.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final entries = d.assetsByAccount.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return Column(
      children: entries.map((e) {
        final accountId = e.key;
        final breakdown = e.value;
        final accountName = d.accountNames[accountId] ?? '账户 $accountId';
        final ratio = total == 0 ? 0.0 : breakdown.total / total;

        return ListTile(
          leading: CircleAvatar(
            child: Text(accountName.substring(0, 1)),
          ),
          title: Text(accountName),
          subtitle: Text(
            '资产: ${breakdown.total.toStringAsFixed(2)} · 占比 ${(ratio * 100).toStringAsFixed(1)}%\n${breakdown.summaryText}',
          ),
          trailing: SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: ratio,
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
  final Map<int, _AccountAssetBreakdown> assetsByAccount;
  final Map<int, String> accountNames;

  _DashboardData({
    required this.totalAssets,
    required this.future6mCf,
    required this.assetsByAccount,
    required this.accountNames,
  });
}

enum _AssetKind {
  deposit,
  financial,
  insurance,
  fund,
}

class _AccountAssetBreakdown {
  double deposit = 0;
  double financial = 0;
  double insurance = 0;
  double fund = 0;

  double get total => deposit + financial + insurance + fund;

  void add(_AssetKind kind, double amount) {
    switch (kind) {
      case _AssetKind.deposit:
        deposit += amount;
        break;
      case _AssetKind.financial:
        financial += amount;
        break;
      case _AssetKind.insurance:
        insurance += amount;
        break;
      case _AssetKind.fund:
        fund += amount;
        break;
    }
  }

  String get summaryText {
    final parts = <String>[];
    if (deposit != 0) parts.add('存款 ${deposit.toStringAsFixed(2)}');
    if (financial != 0) parts.add('理财 ${financial.toStringAsFixed(2)}');
    if (insurance != 0) parts.add('保险 ${insurance.toStringAsFixed(2)}');
    if (fund != 0) parts.add('基金 ${fund.toStringAsFixed(2)}');
    return parts.join(' · ');
  }
}
