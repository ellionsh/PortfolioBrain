import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../api/api_client.dart';

class FinancialProductsPage extends StatefulWidget {
  const FinancialProductsPage({super.key});

  @override
  State<FinancialProductsPage> createState() => _FinancialProductsPageState();
}

class _FinancialProductsPageState extends State<FinancialProductsPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getFinancialProducts();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ApiClient.getFinancialProducts();
    });
  }

  bool _isNavProduct(Map<String, dynamic> product) {
    return product['is_nav_based'] == 1 ||
        product['is_nav_based'] == true ||
        product['type'] == 'nav';
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

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _showProductDialog({Map<String, dynamic>? product}) async {
    final accounts = await ApiClient.getAccounts();
    if (!mounted) return;
    final accountChoices = accounts.cast<Map<String, dynamic>>().map((m) {
      return MapEntry((m['id'] as num).toInt(), m['name'] as String? ?? '');
    }).toList();

    int? selectedAccountId =
        product != null ? (product['account_id'] as num?)?.toInt() : null;
    final nameController =
        TextEditingController(text: product?['product_name'] ?? '');
    final codeController =
        TextEditingController(text: product?['product_code'] ?? '');
    final typeController = TextEditingController(text: product?['type'] ?? '');
    final currencyController =
        TextEditingController(text: product?['currency'] ?? 'CNY');
    bool isNavBased = product != null
        ? (product['is_nav_based'] == 1 || product['is_nav_based'] == true)
        : true;
    final riskController =
        TextEditingController(text: product?['risk_level']?.toString() ?? '');
    final minRedeemController = TextEditingController(
      text: product?['min_redeem_unit']?.toString() ?? '',
    );
    final principalController =
        TextEditingController(text: product?['principal']?.toString() ?? '');
    final navController =
        TextEditingController(text: product?['nav']?.toString() ?? '');
    final sharesController =
        TextEditingController(text: product?['shares']?.toString() ?? '');
    final expectedYieldController = TextEditingController(
      text: product?['expected_yield']?.toString() ?? '',
    );
    final startController = TextEditingController(text: product?['start_date'] ?? '');
    final endController = TextEditingController(text: product?['end_date'] ?? '');
    final payFreqController = TextEditingController(text: product?['pay_freq'] ?? '');
    final statusController = TextEditingController(text: product?['status'] ?? 'active');
    final remarkController = TextEditingController(text: product?['remark'] ?? '');

    final isNew = product == null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isNew ? '新增理财产品' : '编辑理财产品'),
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
                      decoration: const InputDecoration(labelText: '产品名称'),
                    ),
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(labelText: '产品代码'),
                    ),
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(labelText: '类型'),
                    ),
                    TextField(
                      controller: currencyController,
                      decoration: const InputDecoration(labelText: '币种'),
                    ),
                    SwitchListTile(
                      value: isNavBased,
                      title: const Text('净值型产品'),
                      onChanged: (value) {
                        setDialogState(() => isNavBased = value);
                      },
                    ),
                    TextField(
                      controller: riskController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '风险等级'),
                    ),
                    TextField(
                      controller: minRedeemController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '最低赎回单位'),
                    ),
                    TextField(
                      controller: principalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '本金'),
                    ),
                    TextField(
                      controller: navController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '净值'),
                    ),
                    TextField(
                      controller: sharesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '份额'),
                    ),
                    TextField(
                      controller: expectedYieldController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '预期收益'),
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
                      controller: payFreqController,
                      decoration: const InputDecoration(labelText: '支付频率'),
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
                        const SnackBar(content: Text('请填写产品名称和所属账户')),
                      );
                      return;
                    }

                    final params = {
                      'account_id': selectedAccountId,
                      'product_name': nameController.text.trim(),
                      'product_code': codeController.text.trim(),
                      'type': typeController.text.trim(),
                      'currency': currencyController.text.trim().isEmpty
                          ? 'CNY'
                          : currencyController.text.trim(),
                      'is_nav_based': isNavBased,
                      'risk_level': int.tryParse(riskController.text),
                      'min_redeem_unit':
                          double.tryParse(minRedeemController.text),
                      'principal': double.tryParse(principalController.text),
                      'nav': double.tryParse(navController.text),
                      'shares': double.tryParse(sharesController.text),
                      'expected_yield':
                          double.tryParse(expectedYieldController.text),
                      'start_date': startController.text.trim(),
                      'end_date': endController.text.trim(),
                      'pay_freq': payFreqController.text.trim(),
                      'status': statusController.text.trim().isEmpty
                          ? 'active'
                          : statusController.text.trim(),
                      'remark': remarkController.text.trim(),
                    };

                    final action = isNew
                        ? 'financial_product_create'
                        : 'financial_product_update';
                    if (!isNew) {
                      params['id'] = product['id'];
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
      },
    );

    if (result == true) {
      await _refresh();
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除理财产品'),
          content: Text('确认删除理财产品 ${product['product_name'] ?? ''} 吗？'),
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

    final response = await ApiClient.operate(
      'financial_product_delete',
      {'id': product['id']},
    );
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

  Future<void> _buyProduct(Map<String, dynamic> product) async {
    final isNavProduct = _isNavProduct(product);
    final amountController = TextEditingController();
    final navController =
        TextEditingController(text: product['nav']?.toString() ?? '');
    final dateController = TextEditingController(text: _today());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('买入理财产品'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isNavProduct ? '买入金额' : '买入本金',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (isNavProduct) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: navController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '买入净值',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的买入金额')),
                  );
                  return;
                }
                if (isNavProduct && (nav == null || nav <= 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的买入净值')),
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

    if (confirmed != true || amount == null) {
      return;
    }

    final accountId = product['account_id'];
    if (accountId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该产品缺少所属账户')),
      );
      return;
    }

    final action = isNavProduct ? 'financial_buy_nav' : 'financial_buy_fixed';
    final Map<String, dynamic> params = isNavProduct
        ? {
            'product_id': product['id'],
            'account_id': accountId,
            'amount': amount,
            'nav': nav,
            'date': date,
          }
        : {
            'product_id': product['id'],
            'account_id': accountId,
            'principal': amount,
            'date': date,
          };

    final response = await ApiClient.operate(action, params);
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

  Future<void> _redeemProduct(Map<String, dynamic> product) async {
    final isNavProduct = _isNavProduct(product);
    final sharesController =
        TextEditingController(text: product['shares']?.toString() ?? '');
    final navController =
        TextEditingController(text: product['nav']?.toString() ?? '');
    final amountController =
        TextEditingController(text: product['principal']?.toString() ?? '');
    final dateController = TextEditingController(text: _today());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('赎回理财产品'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNavProduct) ...[
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
                ] else
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '兑付金额',
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
                final amount = double.tryParse(amountController.text);
                if (isNavProduct &&
                    (shares == null ||
                        shares <= 0 ||
                        nav == null ||
                        nav <= 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的赎回份额和净值')),
                  );
                  return;
                }
                if (!isNavProduct && (amount == null || amount <= 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的兑付金额')),
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
    final amount = double.tryParse(amountController.text);
    final date = dateController.text.trim();
    sharesController.dispose();
    navController.dispose();
    amountController.dispose();
    dateController.dispose();

    if (confirmed != true) {
      return;
    }

    final accountId = product['account_id'];
    if (accountId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该产品缺少所属账户')),
      );
      return;
    }

    final action = isNavProduct ? 'financial_sell_nav' : 'financial_sell_fixed';
    final Map<String, dynamic> params = isNavProduct
        ? {
            'product_id': product['id'],
            'account_id': accountId,
            'shares': shares,
            'nav': nav,
            'date': date,
          }
        : {
            'product_id': product['id'],
            'account_id': accountId,
            'amount': amount,
            'date': date,
          };

    final response = await ApiClient.operate(action, params);
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
    return SafeArea(
      child: FutureBuilder<List<dynamic>>(
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
                        '理财产品',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => _showProductDialog(),
                      tooltip: '新增',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: data.isEmpty
                    ? const Center(child: Text('暂无理财产品'))
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
                            title: Text(row['product_name'] ?? '理财产品'),
                            subtitle: Text(
                              [
                                row['type'] ?? '',
                                row['product_code'] ?? '',
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
                                if ((row['start_date'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty ||
                                    (row['end_date'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                  '${row['start_date'] ?? ''} ~ ${row['end_date'] ?? ''}',
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
                                  onPressed: () => _buyProduct(row),
                                  tooltip: '买入',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.currency_exchange,
                                    size: 20,
                                  ),
                                  onPressed: () => _redeemProduct(row),
                                  tooltip: '赎回',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _showProductDialog(product: row),
                                  tooltip: '编辑',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _deleteProduct(row),
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
      ),
    );
  }
}
