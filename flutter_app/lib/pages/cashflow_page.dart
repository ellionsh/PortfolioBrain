import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../utils/error_format.dart';
import '../api/api_client.dart';
import '../theme/app_text_styles.dart';

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

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    try {
      return DateTime.parse(text);
    } catch (_) {
      return null;
    }
  }

  double? _annualizedYieldForFund(Map<String, dynamic> m) {
    final shares = _parseDouble(m['shares']);
    final nav = _parseDouble(m['nav']);
    final principal = _parseDouble(m['principal']);
    final principalCny = _parseDouble(m['principal_cny']);
    final marketValueCny = _parseDouble(m['market_value_cny']);
    final marketValue = (shares != null && nav != null) ? shares * nav : null;
    final displayMarketValue = marketValueCny ?? marketValue;
    final displayPrincipal = principalCny ?? principal;
    final yieldRate =
        (displayMarketValue != null && displayPrincipal != null && displayPrincipal > 0)
            ? (displayMarketValue - displayPrincipal) / displayPrincipal
            : null;
    final startDate = _parseDate(m['start_date']);
    if (yieldRate != null && startDate != null && yieldRate > -1) {
      final days = DateTime.now().difference(startDate).inDays;
      if (days > 0) {
        return math.pow(1 + yieldRate, 365 / days) - 1;
      }
    }
    return null;
  }

  double? _annualizedYieldValue(Map<String, dynamic> m,
      {bool isBank = false, bool isFund = false}) {
    if (isBank) {
      return _parseDouble(m['interest_rate']);
    }
    if (isFund) {
      return _annualizedYieldForFund(m);
    }
    return _parseDouble(m['annualized_yield']);
  }

  String? _yieldStr(Map<String, dynamic> m, {bool isBank = false, bool isFund = false}) {
    if (isBank) {
      final rate = _parseDouble(m['interest_rate']);
      if (rate == null) return null;
      return '${(rate * 100).toStringAsFixed(2)}%';
    }
    if (isFund) {
      final annualized = _annualizedYieldForFund(m);
      if (annualized != null) {
        return '${(annualized * 100).toStringAsFixed(2)}%';
      }
      return null;
    }
    final annualized = _parseDouble(m['annualized_yield']);
    if (annualized != null) {
      return '${(annualized * 100).toStringAsFixed(2)}%';
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
        yieldValue: _annualizedYieldValue(m, isBank: true),
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
        yieldValue: _annualizedYieldValue(m),
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
        yieldStr: _yieldStr(m, isFund: true),
        yieldValue: _annualizedYieldValue(m, isFund: true),
        type: '基金',
      ));
    }

    _sortBucketItems(buckets);
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
                const Text('资产到期分布', style: AppTextStyles.pageTitle),
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
                                          style: AppTextStyles.sectionTitle),
                                    ),
                                    if (b.items.isNotEmpty)
                                      Icon(expanded ? Icons.expand_less : Icons.expand_more,
                                          size: 20, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      b.total.toStringAsFixed(2),
                                      style: AppTextStyles.sectionValue,
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
                                  style: AppTextStyles.caption,
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
                                          style: AppTextStyles.badge),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name,
                                              style: AppTextStyles.body,
                                              overflow: TextOverflow.ellipsis),
                                          Text(
                                            [
                                              item.accountName,
                                              if (item.endDate != null) '到期 ${item.endDate}',
                                              if (item.yieldStr != null) item.yieldStr!,
                                            ].join(' · '),
                                            style: AppTextStyles.label,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      item.value.toStringAsFixed(2),
                                      style: AppTextStyles.bodyStrong,
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

  void _sortBucketItems(List<_MaturityBucket> buckets) {
    const typeOrder = {'存款': 0, '理财': 1, '基金': 2};
    for (final bucket in buckets) {
      bucket.items.sort((a, b) {
        final orderA = typeOrder[a.type] ?? 99;
        final orderB = typeOrder[b.type] ?? 99;
        if (orderA != orderB) return orderA.compareTo(orderB);
        final yieldA = a.yieldValue;
        final yieldB = b.yieldValue;
        if (yieldA == null && yieldB == null) return 0;
        if (yieldA == null) return 1;
        if (yieldB == null) return -1;
        final yieldCompare = yieldA.compareTo(yieldB);
        if (yieldCompare != 0) return yieldCompare;
        return a.name.compareTo(b.name);
      });
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
  final double? yieldValue;
  final String type;

  const _AssetItem({
    required this.accountName,
    required this.name,
    required this.value,
    this.endDate,
    this.yieldStr,
    this.yieldValue,
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
