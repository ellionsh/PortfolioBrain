import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../utils/error_format.dart';
import '../theme/app_text_styles.dart';

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
    final positionsSummary = await ApiClient.getPositionsSummary();

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

    final marketValueSeries = _buildSeries(positionsSummary);
    final avgYieldSeries = _buildYieldSeries(positionsSummary);

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
      marketValueSeries: marketValueSeries,
      avgYieldSeries: avgYieldSeries,
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
                const Text('资产总览', style: AppTextStyles.pageTitle),
                const SizedBox(height: 16),
                _buildSummaryCards(data),
                const SizedBox(height: 24),
                const Text('市值趋势', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 8),
                _buildMarketValueChart(data),
                const SizedBox(height: 24),
                const Text('平均年化收益率趋势', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 8),
                _buildYieldChart(data),
                const SizedBox(height: 24),
                const Text('资产分布（按账户）', style: AppTextStyles.sectionTitle),
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
                style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTextStyles.sectionValue.copyWith(color: valueColor),
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
                      style: AppTextStyles.hint),
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

  Widget _buildMarketValueChart(_DashboardData d) {
    if (d.marketValueSeries.isEmpty) {
      return const Text('暂无历史持仓汇总');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _MultiLineChartPainter(
                  series: d.marketValueSeries,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegend(d.marketValueSeries, showValue: true),
          ],
        ),
      ),
    );
  }

  Widget _buildYieldChart(_DashboardData d) {
    if (d.avgYieldSeries.isEmpty) {
      return const Text('暂无年化收益率数据');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _MultiLineChartPainter(
                  series: d.avgYieldSeries,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegend(d.avgYieldSeries, showValue: true, valueSuffix: '%'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(List<_DailySeries> series, {bool showValue = false, String valueSuffix = ''}) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: series.map((s) {
        final latest = s.points.isNotEmpty ? s.points.last.value : null;
        final valueText = latest == null ? '' : ' ${latest.toStringAsFixed(2)}$valueSuffix';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 2, color: s.color),
            const SizedBox(width: 6),
            Text('${s.label}${showValue ? valueText : ''}', style: AppTextStyles.hint),
          ],
        );
      }).toList(),
    );
  }

  List<_DailySeries> _buildSeries(List<dynamic> rows) {
    final total = <_DailyPoint>[];
    final bank = <_DailyPoint>[];
    final financial = <_DailyPoint>[];
    final insurance = <_DailyPoint>[];
    final fund = <_DailyPoint>[];
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      final dateStr = m['date'] as String?;
      if (dateStr == null || dateStr.isEmpty) continue;
      final date = DateTime.parse(dateStr);
      total.add(_DailyPoint(date, (m['total_market_value_cny'] as num?)?.toDouble() ?? 0));
      bank.add(_DailyPoint(date, (m['bank_market_value_cny'] as num?)?.toDouble() ?? 0));
      financial.add(_DailyPoint(date, (m['financial_market_value_cny'] as num?)?.toDouble() ?? 0));
      insurance.add(_DailyPoint(date, (m['insurance_market_value_cny'] as num?)?.toDouble() ?? 0));
      fund.add(_DailyPoint(date, (m['fund_market_value_cny'] as num?)?.toDouble() ?? 0));
    }
    total.sort((a, b) => a.date.compareTo(b.date));
    bank.sort((a, b) => a.date.compareTo(b.date));
    financial.sort((a, b) => a.date.compareTo(b.date));
    insurance.sort((a, b) => a.date.compareTo(b.date));
    fund.sort((a, b) => a.date.compareTo(b.date));
    return [
      _DailySeries('总市值', total, Colors.blue),
      _DailySeries('存款', bank, Colors.teal),
      _DailySeries('理财', financial, Colors.orange),
      _DailySeries('保险', insurance, Colors.purple),
      _DailySeries('基金', fund, Colors.green),
    ];
  }

  List<_DailySeries> _buildYieldSeries(List<dynamic> rows) {
    final total = <_DailyPoint>[];
    final bank = <_DailyPoint>[];
    final financial = <_DailyPoint>[];
    final insurance = <_DailyPoint>[];
    final fund = <_DailyPoint>[];
    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      final dateStr = m['date'] as String?;
      if (dateStr == null || dateStr.isEmpty) continue;
      final date = DateTime.parse(dateStr);
      final vTotal = (m['avg_annual_yield_rate_total'] as num?)?.toDouble();
      final vBank = (m['avg_annual_yield_rate_bank'] as num?)?.toDouble();
      final vFinancial = (m['avg_annual_yield_rate_financial'] as num?)?.toDouble();
      final vInsurance = (m['avg_annual_yield_rate_insurance'] as num?)?.toDouble();
      final vFund = (m['avg_annual_yield_rate_fund'] as num?)?.toDouble();
      if (vTotal != null) total.add(_DailyPoint(date, vTotal * 100));
      if (vBank != null) bank.add(_DailyPoint(date, vBank * 100));
      if (vFinancial != null) financial.add(_DailyPoint(date, vFinancial * 100));
      if (vInsurance != null) insurance.add(_DailyPoint(date, vInsurance * 100));
      if (vFund != null) fund.add(_DailyPoint(date, vFund * 100));
    }
    total.sort((a, b) => a.date.compareTo(b.date));
    bank.sort((a, b) => a.date.compareTo(b.date));
    financial.sort((a, b) => a.date.compareTo(b.date));
    insurance.sort((a, b) => a.date.compareTo(b.date));
    fund.sort((a, b) => a.date.compareTo(b.date));
    return [
      _DailySeries('总平均', total, Colors.redAccent),
      _DailySeries('存款', bank, Colors.teal),
      _DailySeries('理财', financial, Colors.orange),
      _DailySeries('保险', insurance, Colors.purple),
      _DailySeries('基金', fund, Colors.green),
    ];
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
  final List<_DailySeries> marketValueSeries;
  final List<_DailySeries> avgYieldSeries;

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
    required this.marketValueSeries,
    required this.avgYieldSeries,
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

class _DailyPoint {
  final DateTime date;
  final double value;

  _DailyPoint(this.date, this.value);
}

class _DailySeries {
  final String label;
  final List<_DailyPoint> points;
  final Color color;

  _DailySeries(this.label, this.points, this.color);
}

class _MultiLineChartPainter extends CustomPainter {
  final List<_DailySeries> series;

  _MultiLineChartPainter({required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) {
      return;
    }
    final allPoints = series.expand((s) => s.points).toList();
    if (allPoints.length < 2) return;
    allPoints.sort((a, b) => a.date.compareTo(b.date));
    final minDate = allPoints.first.date;
    final maxDate = allPoints.last.date;
    final minValue = allPoints.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxValue = allPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final valueRange = (maxValue - minValue).abs();
    final dayRange = maxDate.difference(minDate).inDays;
    final effectiveDayRange = dayRange == 0 ? 1 : dayRange;

    for (final s in series) {
      if (s.points.length < 2) continue;
      final paintLine = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final path = Path();
      for (var i = 0; i < s.points.length; i++) {
        final p = s.points[i];
        final dx = (p.date.difference(minDate).inDays / effectiveDayRange) * size.width;
        final normalized = valueRange == 0 ? 0.5 : (p.value - minValue) / valueRange;
        final dy = size.height - (normalized * size.height);
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
      canvas.drawPath(path, paintLine);
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}
