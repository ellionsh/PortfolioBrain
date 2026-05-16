import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../api/api_client.dart';

class FundProductsPage extends StatefulWidget {
  const FundProductsPage({super.key});

  @override
  State<FundProductsPage> createState() => _FundProductsPageState();
}

class _FundProductsPageState extends State<FundProductsPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getFundProducts();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ApiClient.getFundProducts();
    });
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

  String _formatNumber(double? value, {int fraction = 2}) {
    if (value == null) return '';
    return value.toStringAsFixed(fraction);
  }

  String _formatPercent(double? value, {int fraction = 2}) {
    if (value == null) return '';
    return '${(value * 100).toStringAsFixed(fraction)}%';
  }

  String _formatDateRange(dynamic start, dynamic end) {
    final startText = (start ?? '').toString().trim();
    final endText = (end ?? '').toString().trim();
    if (startText.isEmpty && endText.isEmpty) return '';
    final displayStart = startText.isEmpty ? '至今' : startText;
    final displayEnd = endText.isEmpty ? '至今' : endText;
    if (displayStart == displayEnd) return displayStart;
    return '$displayStart ~ $displayEnd';
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _showFundDialog({Map<String, dynamic>? fund}) async {
    final accounts = await ApiClient.getAccounts();
    if (!mounted) return;
    final accountChoices = accounts
        .cast<Map<String, dynamic>>()
        .map(
          (m) => MapEntry(
            (m['id'] as num).toInt(),
            m['name'] as String? ?? '',
          ),
        )
        .toList();

    int? selectedAccountId =
        fund != null ? (fund['account_id'] as num?)?.toInt() : null;
    final nameController =
        TextEditingController(text: fund?['fund_name'] ?? '');
    final codeController =
        TextEditingController(text: fund?['fund_code'] ?? '');
    final currencyController =
        TextEditingController(text: fund?['currency'] ?? 'CNY');
    final sharesController =
        TextEditingController(text: fund?['shares']?.toString() ?? '');
    final navController =
        TextEditingController(text: fund?['nav']?.toString() ?? '');
    final principalController =
        TextEditingController(text: fund?['principal']?.toString() ?? '');
    final startController =
        TextEditingController(text: fund?['start_date'] ?? '');
    final endController = TextEditingController(text: fund?['end_date'] ?? '');
    final statusController =
        TextEditingController(text: fund?['status'] ?? 'active');
    final remarkController = TextEditingController(text: fund?['remark'] ?? '');

    final isNew = fund == null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? '新增基金产品' : '编辑基金产品'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedAccountId,
                  items: accountChoices
                      .map((entry) => DropdownMenuItem<int>(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(),
                  onChanged: (value) => selectedAccountId = value,
                  decoration: const InputDecoration(labelText: '所属账户'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '基金名称'),
                ),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: '基金代码'),
                ),
                TextField(
                  controller: currencyController,
                  decoration: const InputDecoration(labelText: '币种'),
                ),
                TextField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '当前份额'),
                ),
                TextField(
                  controller: navController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '净值'),
                ),
                TextField(
                  controller: principalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '成本'),
                ),
                TextField(
                  controller: startController,
                  decoration:
                      const InputDecoration(labelText: '开始日期 (YYYY-MM-DD)'),
                ),
                TextField(
                  controller: endController,
                  decoration:
                      const InputDecoration(labelText: '结束日期 (YYYY-MM-DD)'),
                ),
                TextField(
                  controller: statusController,
                  decoration: const InputDecoration(labelText: '状态'),
                ),
                TextField(
                  controller: remarkController,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedAccountId == null ||
                    nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写基金名称和所属账户')),
                  );
                  return;
                }

                final params = {
                  'account_id': selectedAccountId,
                  'fund_name': nameController.text.trim(),
                  'fund_code': codeController.text.trim(),
                  'currency': currencyController.text.trim().isEmpty
                      ? 'CNY'
                      : currencyController.text.trim(),
                  'shares': double.tryParse(sharesController.text) ?? 0,
                  'nav': double.tryParse(navController.text),
                  'principal':
                      double.tryParse(principalController.text) ?? 0,
                  'start_date': startController.text.trim(),
                  'end_date': endController.text.trim(),
                  'status': statusController.text.trim().isEmpty
                      ? 'active'
                      : statusController.text.trim(),
                  'remark': remarkController.text.trim(),
                };

                final action =
                    isNew ? 'fund_product_create' : 'fund_product_update';
                if (!isNew) {
                  params['id'] = fund['id'];
                }

                final response = await ApiClient.operate(action, params);
                if (!context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                if (response.containsKey('error')) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(response['error'].toString())),
                  );
                  return;
                }

                navigator.pop(true);
              },
              child: Text(isNew ? '新增' : '保存'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _refresh();
    }
  }

  Future<void> _deleteFund(Map<String, dynamic> fund) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除基金产品'),
          content: Text('确认删除基金产品 ${fund['fund_name'] ?? ''} 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final response =
        await ApiClient.operate('fund_product_delete', {'id': fund['id']});
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      messenger.showSnackBar(
        SnackBar(content: Text(response['error'].toString())),
      );
      return;
    }

    await _refresh();
  }

  Future<void> _buyFund(Map<String, dynamic> fund) async {
    final amountController = TextEditingController();
    final navController =
        TextEditingController(text: fund['nav']?.toString() ?? '');
    final dateController = TextEditingController(text: _today());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('买入基金'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '买入金额',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: navController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '买入净值',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: '买入日期 (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                final nav = double.tryParse(navController.text);
                if (amount == null || amount <= 0 || nav == null || nav <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的买入金额和净值')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('买入'),
            ),
          ],
        );
      },
    );

    final amount = double.tryParse(amountController.text);
    final nav = double.tryParse(navController.text);
    final date = dateController.text.trim();
    amountController.dispose();
    navController.dispose();
    dateController.dispose();

    if (confirmed != true || amount == null || nav == null) {
      return;
    }

    final accountId = fund['account_id'];
    if (accountId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该基金缺少所属账户')),
      );
      return;
    }

    final response = await ApiClient.operate('fund_buy', {
      'fund_id': fund['id'],
      'account_id': accountId,
      'amount': amount,
      'nav': nav,
      'date': date,
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      messenger.showSnackBar(
        SnackBar(content: Text(response['error'].toString())),
      );
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('买入成功')));
    await _refresh();
  }

  Future<void> _redeemFund(Map<String, dynamic> fund) async {
    final sharesController =
        TextEditingController(text: fund['shares']?.toString() ?? '');
    final navController =
        TextEditingController(text: fund['nav']?.toString() ?? '');
    final dateController = TextEditingController(text: _today());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('赎回基金'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '赎回份额',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: navController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '赎回净值',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: '赎回日期 (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final shares = double.tryParse(sharesController.text);
                final nav = double.tryParse(navController.text);
                if (shares == null || shares <= 0 || nav == null || nav <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的赎回份额和净值')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('赎回'),
            ),
          ],
        );
      },
    );

    final shares = double.tryParse(sharesController.text);
    final nav = double.tryParse(navController.text);
    final date = dateController.text.trim();
    sharesController.dispose();
    navController.dispose();
    dateController.dispose();

    if (confirmed != true || shares == null || nav == null) {
      return;
    }

    final accountId = fund['account_id'];
    if (accountId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该基金缺少所属账户')),
      );
      return;
    }

    final response = await ApiClient.operate('fund_sell', {
      'fund_id': fund['id'],
      'account_id': accountId,
      'shares': shares,
      'nav': nav,
      'date': date,
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      messenger.showSnackBar(
        SnackBar(content: Text(response['error'].toString())),
      );
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('赎回成功')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }
        final data = snapshot.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '基金产品',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => _showFundDialog(),
                    tooltip: '新增',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Expanded(
              child: data.isEmpty
                  ? const Center(child: Text('暂无基金产品'))
                  : ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, i) {
                        final row = data[i] as Map<String, dynamic>;
                        final shares = _parseDouble(row['shares']);
                        final nav = _parseDouble(row['nav']);
                        final principal = _parseDouble(row['principal']);
                        final marketValue = (shares != null && nav != null)
                            ? shares * nav
                            : null;
                        final yieldRate = (marketValue != null &&
                                principal != null &&
                                principal > 0)
                            ? (marketValue - principal) / principal
                            : null;
                        final startDate = _parseDate(row['start_date']);
                        double? annualizedYield;
                        if (yieldRate != null &&
                            startDate != null &&
                            yieldRate > -1) {
                          final days =
                              DateTime.now().difference(startDate).inDays;
                          if (days > 0) {
                            annualizedYield =
                                math.pow(1 + yieldRate, 365 / days) - 1;
                          }
                        }
                        return ListTile(
                          title: Text(row['fund_name'] ?? '基金产品'),
                          subtitle: Text(
                            [
                              row['fund_code'] ?? '',
                              if (principal != null)
                                '成本 ${_formatNumber(principal)}',
                              if (nav != null) '净值 ${_formatNumber(nav)}',
                              if (shares != null)
                                '份额 ${_formatNumber(shares)}',
                              if (marketValue != null)
                                '市值 ${_formatNumber(marketValue)}',
                              if (yieldRate != null)
                                '收益率 ${_formatPercent(yieldRate)}',
                              if (annualizedYield != null)
                                '年化 ${_formatPercent(annualizedYield)}',
                              if (_formatDateRange(
                                    row['start_date'],
                                    row['end_date'],
                                  ).isNotEmpty)
                                _formatDateRange(
                                  row['start_date'],
                                  row['end_date'],
                                ),
                            ]
                                .where((text) =>
                                    text.toString().trim().isNotEmpty)
                                .join(' · '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 20,
                                ),
                                onPressed: () => _buyFund(row),
                                tooltip: '买入',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.currency_exchange,
                                  size: 20,
                                ),
                                onPressed: () => _redeemFund(row),
                                tooltip: '赎回',
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showFundDialog(fund: row),
                                tooltip: '编辑',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () => _deleteFund(row),
                                tooltip: '删除',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
