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

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  double _marketValueCny(Map<String, dynamic> m) {
    final principal = (m['principal'] as num?)?.toDouble() ?? 0;
    final shares = (m['shares'] as num?)?.toDouble() ?? 0;
    final nav = (m['nav'] as num?)?.toDouble();
    final amount = nav == null ? principal : shares * nav;
    return (m['market_value_cny'] as num?)?.toDouble() ?? amount;
  }

  Future<_DashboardData> _load() async {
    final summary = await ApiClient.getSummary();
    final accounts = await ApiClient.getAccounts();
    final deposits = await ApiClient.getBankDeposits();
    final financialProducts = await ApiClient.getFinancialProducts();
    final insuranceProducts = await ApiClient.getInsurance();
    final fundProducts = await ApiClient.getFundProducts();

    final todayStr = _todayStr();

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

    double totalDeposit = 0;
    double totalFinancial = 0;
    double totalInsurance = 0;
    double totalFund = 0;
    double availableDeposit = 0;
    double availableFinancial = 0;
    double availableFund = 0;

    for (final row in deposits) {
      final m = row as Map<String, dynamic>;
      final depositType = m['deposit_type'] as String?;
      final endDate = m['end_date'] as String?;
      final principal = (m['principal'] as num?)?.toDouble() ?? 0;
      totalDeposit += principal;
      if (depositType == '活期' || depositType == 'demand' || endDate == null || endDate.compareTo(todayStr) <= 0) {
        availableDeposit += principal;
      }
      addAsset(
        (m['account_id'] as num?)?.toInt(),
        principal,
        _AssetKind.deposit,
      );
    }

    for (final row in financialProducts) {
      final m = row as Map<String, dynamic>;
      final endDate = m['end_date'] as String?;
      final amountCny = _marketValueCny(m);
      totalFinancial += amountCny;
      if (endDate == null || endDate.compareTo(todayStr) <= 0) {
        availableFinancial += amountCny;
      }
      addAsset(
        (m['account_id'] as num?)?.toInt(),
        amountCny,
        _AssetKind.financial,
      );
    }

    for (final row in insuranceProducts) {
      final m = row as Map<String, dynamic>;
      final cashValue = (m['cash_value'] as num?)?.toDouble();
      final premium = (m['premium'] as num?)?.toDouble() ?? 0;
      final value = cashValue ?? premium;
      totalInsurance += value;
      addAsset(
        (m['account_id'] as num?)?.toInt(),
        value,
        _AssetKind.insurance,
      );
    }

    for (final row in fundProducts) {
      final m = row as Map<String, dynamic>;
      final endDate = m['end_date'] as String?;
      final amountCny = _marketValueCny(m);
      totalFund += amountCny;
      if (endDate == null || endDate.compareTo(todayStr) <= 0) {
        availableFund += amountCny;
      }
      addAsset(
        (m['account_id'] as num?)?.toInt(),
        amountCny,
        _AssetKind.fund,
      );
    }

    return _DashboardData(
      totalAssets: (summary['total_assets'] as num?)?.toDouble() ?? 0,
      future6mCf: availableDeposit + availableFinancial + availableFund,
      totalDeposit: totalDeposit,
      totalFinancial: totalFinancial,
      totalInsurance: totalInsurance,
      totalFund: totalFund,
      availableDeposit: availableDeposit,
      availableFinancial: availableFinancial,
      availableFund: availableFund,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _assetCard('总资产', d.totalAssets.toStringAsFixed(2), null, [
            '存款 ${d.totalDeposit.toStringAsFixed(2)}',
            '理财 ${d.totalFinancial.toStringAsFixed(2)}',
            '保险 ${d.totalInsurance.toStringAsFixed(2)}',
            '基金 ${d.totalFund.toStringAsFixed(2)}',
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _assetCard('1天内可用资金', d.future6mCf.toStringAsFixed(2),
              d.future6mCf >= 0 ? Colors.green : Colors.red, [
            '存款 ${d.availableDeposit.toStringAsFixed(2)}',
            '理财 ${d.availableFinancial.toStringAsFixed(2)}',
            '保险 ${d.availableInsurance.toStringAsFixed(2)}',
            '基金 ${d.availableFund.toStringAsFixed(2)}',
          ]),
        ),
      ],
    );
  }

  Widget _assetCard(String title, String value, Color? valueColor, List<String> breakdowns) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600, color: valueColor),
              ),
            ),
            const Divider(height: 16),
            for (final line in breakdowns)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(line,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
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
          trailing: null,
        );
      }).toList(),
    );
  }


}

class _DashboardData {
  final double totalAssets;
  final double future6mCf;
  final double totalDeposit;
  final double totalFinancial;
  final double totalInsurance;
  final double totalFund;
  final double availableDeposit;
  final double availableFinancial;
  final double availableInsurance;
  final double availableFund;
  final Map<int, _AccountAssetBreakdown> assetsByAccount;
  final Map<int, String> accountNames;

  _DashboardData({
    required this.totalAssets,
    required this.future6mCf,
    required this.totalDeposit,
    required this.totalFinancial,
    required this.totalInsurance,
    required this.totalFund,
    required this.availableDeposit,
    required this.availableFinancial,
    required this.availableFund,
    required this.assetsByAccount,
    required this.accountNames,
  }) : availableInsurance = 0;
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
