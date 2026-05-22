import 'package:flutter/material.dart';

import '../utils/error_format.dart';
import '../api/api_client.dart';

class CashflowPage extends StatefulWidget {
  const CashflowPage({super.key});

  @override
  State<CashflowPage> createState() => _CashflowPageState();
}

class _CashflowPageState extends State<CashflowPage> {
  late Future<_MaturityData> _future;
  final Set<int> _expandedBuckets = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _addDays(String dateStr, int days) {
    final date = DateTime.parse(dateStr);
    final result = date.add(Duration(days: days));
    return '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}';
  }

  double _marketValueCny(Map<String, dynamic> m) {
    final principal = (m['principal'] as num?)?.toDouble() ?? 0;
    final shares = (m['shares'] as num?)?.toDouble() ?? 0;
    final nav = (m['nav'] as num?)?.toDouble();
    final amount = nav == null ? principal : shares * nav;
    return (m['market_value_cny'] as num?)?.toDouble() ?? amount;
  }

  String? _yieldStr(Map<String, dynamic> m, {bool isBank = false}) {
    if (isBank) {
      final rate = m['interest_rate'] as num?;
      if (rate == null) return null;
      return '${(rate.toDouble() * 100).toStringAsFixed(2)}%';
    }
    final annualized = m['annualized_yield'] as num?;
    if (annualized != null) {
      return '${(annualized.toDouble() * 100).toStringAsFixed(2)}%';
    }
    final expected = m['expected_yield'] as num?;
    if (expected != null) {
      return '${(expected.toDouble() * 100).toStringAsFixed(2)}%';
    }
    return null;
  }

  int _maturityBucket(String? endDate, String todayStr,
      String day7Str, String day30Str, String day90Str,
      String day365Str, String day1825Str,
      {String? depositType}) {
    if (depositType == '活期' || depositType == 'demand') return 0;
    if (endDate == null) return 0;
    if (endDate.compareTo(todayStr) <= 0) return 0;
    if (endDate.compareTo(day7Str) <= 0) return 1;
    if (endDate.compareTo(day30Str) <= 0) return 2;
    if (endDate.compareTo(day90Str) <= 0) return 3;
    if (endDate.compareTo(day365Str) <= 0) return 4;
    if (endDate.compareTo(day1825Str) <= 0) return 5;
    return 6;
  }

  Future<_MaturityData> _load() async {
    final accounts = await ApiClient.getAccounts();
    final deposits = await ApiClient.getBankDeposits();
    final financialProducts = await ApiClient.getFinancialProducts();
    final fundProducts = await ApiClient.getFundProducts();

    final Map<int, String> accountNames = {};
    for (final row in accounts) {
      final m = row as Map<String, dynamic>;
      final id = (m['id'] as num).toInt();
      final name = m['name'] as String? ?? '未命名账户';
      accountNames[id] = name;
    }

    final todayStr = _todayStr();
    final day7Str = _addDays(todayStr, 7);
    final day30Str = _addDays(todayStr, 30);
    final day90Str = _addDays(todayStr, 90);
    final day365Str = _addDays(todayStr, 365);
    final day1825Str = _addDays(todayStr, 1825);

    final buckets = List.generate(7, (_) => _MaturityBucket());

    for (final row in deposits) {
      final m = row as Map<String, dynamic>;
      final endDate = m['end_date'] as String?;
      final depositType = m['deposit_type'] as String? ?? '';
      final val = (m['principal'] as num?)?.toDouble() ?? 0;
      final idx = _maturityBucket(
        endDate, todayStr, day7Str, day30Str, day90Str, day365Str, day1825Str,
        depositType: depositType,
      );
      final aid = (m['account_id'] as num?)?.toInt();
      buckets[idx].deposit += val;
      buckets[idx].total += val;
      buckets[idx].items.add(_AssetItem(
        accountName: aid != null ? (accountNames[aid] ?? '账户 $aid') : '未知账户',
        name: depositType == '活期' || depositType == 'demand' ? '活期存款' : '定期存款',
        value: val,
        endDate: endDate,
        yieldStr: _yieldStr(m, isBank: true),
        type: '存款',
      ));
    }

    for (final row in financialProducts) {
      final m = row as Map<String, dynamic>;
      final endDate = m['end_date'] as String?;
      final val = _marketValueCny(m);
      final idx = _maturityBucket(
        endDate, todayStr, day7Str, day30Str, day90Str, day365Str, day1825Str,
      );
      final aid = (m['account_id'] as num?)?.toInt();
      buckets[idx].financial += val;
      buckets[idx].total += val;
      buckets[idx].items.add(_AssetItem(
        accountName: aid != null ? (accountNames[aid] ?? '账户 $aid') : '未知账户',
        name: m['product_name'] as String? ?? '理财产品',
        value: val,
        endDate: endDate,
        yieldStr: _yieldStr(m),
        type: '理财',
      ));
    }

    for (final row in fundProducts) {
      final m = row as Map<String, dynamic>;
      final endDate = m['end_date'] as String?;
      final val = _marketValueCny(m);
      final idx = _maturityBucket(
        endDate, todayStr, day7Str, day30Str, day90Str, day365Str, day1825Str,
      );
      final aid = (m['account_id'] as num?)?.toInt();
      buckets[idx].fund += val;
      buckets[idx].total += val;
      buckets[idx].items.add(_AssetItem(
        accountName: aid != null ? (accountNames[aid] ?? '账户 $aid') : '未知账户',
        name: m['fund_name'] as String? ?? '基金产品',
        value: val,
        endDate: endDate,
        yieldStr: _yieldStr(m),
        type: '基金',
      ));
    }

    return _MaturityData(buckets: buckets);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_MaturityData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${formatApiError(snapshot.error!)}'));
          }
          final data = snapshot.data!;
          final allZero = data.buckets.every((b) => b.total == 0);
          if (allZero) {
            return const Center(child: Text('暂无资产数据'));
          }
          final totalAll = data.buckets.fold<double>(0, (s, b) => s + b.total);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const Text('资产到期分布',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...List.generate(_bucketLabels.length, (i) {
                  final b = data.buckets[i];
                  if (b.total == 0) return const SizedBox.shrink();
                  final ratio = totalAll == 0 ? 0.0 : b.total / totalAll;
                  final expanded = _expandedBuckets.contains(i);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: b.items.isEmpty ? null : () {
                            setState(() {
                              if (expanded) {
                                _expandedBuckets.remove(i);
                              } else {
                                _expandedBuckets.add(i);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(_bucketLabels[i],
                                          style: const TextStyle(
                                              fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                    if (b.items.isNotEmpty)
                                      Icon(expanded ? Icons.expand_less : Icons.expand_more,
                                          size: 20, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      b.total.toStringAsFixed(2),
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 6,
                                    backgroundColor: Colors.grey.shade200,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    if (b.deposit != 0) '存款 ${b.deposit.toStringAsFixed(2)}',
                                    if (b.financial != 0) '理财 ${b.financial.toStringAsFixed(2)}',
                                    if (b.fund != 0) '基金 ${b.fund.toStringAsFixed(2)}',
                                  ].join('  ·  '),
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (expanded && b.items.isNotEmpty) ...[
                          const Divider(height: 1, indent: 12, endIndent: 12),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: b.items.map((item) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _typeColor(item.type),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(item.type,
                                          style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name,
                                              style: const TextStyle(fontSize: 14),
                                              overflow: TextOverflow.ellipsis),
                                          Text(
                                            [
                                              item.accountName,
                                              if (item.endDate != null) '到期 ${item.endDate}',
                                              if (item.yieldStr != null) item.yieldStr!,
                                            ].join(' · '),
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      item.value.toStringAsFixed(2),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case '存款':
        return Colors.blue;
      case '理财':
        return Colors.orange;
      case '基金':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

const _bucketLabels = [
  '活期资产',
  '7天内到期',
  '一个月内到期',
  '三个月内到期',
  '1年内到期',
  '5年内到期',
  '5年以上',
];

class _AssetItem {
  final String accountName;
  final String name;
  final double value;
  final String? endDate;
  final String? yieldStr;
  final String type;

  const _AssetItem({
    required this.accountName,
    required this.name,
    required this.value,
    this.endDate,
    this.yieldStr,
    required this.type,
  });
}

class _MaturityBucket {
  double total = 0;
  double deposit = 0;
  double financial = 0;
  double fund = 0;
  final List<_AssetItem> items = [];
}

class _MaturityData {
  final List<_MaturityBucket> buckets;

  const _MaturityData({required this.buckets});
}
