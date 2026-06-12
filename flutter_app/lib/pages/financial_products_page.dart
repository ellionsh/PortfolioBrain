import 'package:flutter/material.dart';

import '../utils/error_format.dart';
import '../api/api_client.dart';
import '../theme/app_text_styles.dart';

class FinancialProductsPage extends StatefulWidget {
  const FinancialProductsPage({super.key});

  @override
  State<FinancialProductsPage> createState() => _FinancialProductsPageState();
}

class _FinancialProductsPageState extends State<FinancialProductsPage> {
  late Future<_FinancialProductsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<_FinancialProductsData> _load() async {
    final accounts = await ApiClient.getAccounts();
    final products = await ApiClient.getFinancialProducts();

    final Map<int, String> accountNames = {};
    for (final row in accounts) {
      final m = row as Map<String, dynamic>;
      final id = (m['id'] as num).toInt();
      final name = m['name'] as String? ?? '未命名账户';
      accountNames[id] = name;
    }

    return _FinancialProductsData(
      products: products,
      accountNames: accountNames,
    );
  }

  Future<Map<String, dynamic>?> _fetchProductById(int id) async {
    final products = await ApiClient.getFinancialProducts();
    for (final row in products) {
      final m = row as Map<String, dynamic>;
      if ((m['id'] as num?)?.toInt() == id) {
        return m;
      }
    }
    return null;
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

  String _formatNav(double? value) => _formatNumber(value, fraction: 6);

  String _formatPercent(double? value, {int fraction = 2}) {
    if (value == null) return '';
    return '${(value * 100).toStringAsFixed(fraction)}%';
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Widget _buildInfoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: AppTextStyles.hint),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _showProductDetail(Map<String, dynamic> product) async {
    Map<String, dynamic> current = Map<String, dynamic>.from(product);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> refreshDetail() async {
              final id = (current['id'] as num?)?.toInt();
              if (id == null) return;
              final latest = await _fetchProductById(id);
              if (!mounted || latest == null) return;
              setDialogState(() {
                current = latest;
              });
            }

            final isNavProduct = _isNavProduct(current);
            final shares = _parseDouble(current['shares']);
            final nav = _parseDouble(current['nav']);
            final principal = _parseDouble(current['principal']);
            final principalCny = _parseDouble(current['principal_cny']);
            final marketValueCny = _parseDouble(current['market_value_cny']);
            double? marketValue;
            if (isNavProduct) {
              if (shares != null && nav != null) {
                marketValue = shares * nav;
              }
            } else {
              if (shares != null) {
                marketValue = shares;
              }
            }
            final displayMarketValue = marketValueCny ?? marketValue;
            final displayPrincipal = principalCny ?? principal;
            final yieldRate =
                (displayMarketValue != null &&
                        displayPrincipal != null &&
                        displayPrincipal > 0)
                    ? (displayMarketValue - displayPrincipal) / displayPrincipal
                    : null;
            final annualizedYield = _parseDouble(current['annualized_yield']);

            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              title: Text(current['product_name'] ?? '理财产品详情'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _buildInfoRow(
                        '产品代码', (current['product_code'] ?? '').toString()),
                    _buildInfoRow('类型', (current['type'] ?? '').toString()),
                    _buildInfoRow('币种', (current['currency'] ?? '').toString()),
                    _buildInfoRow(
                        '风险等级', (current['risk_level'] ?? '').toString()),
                    _buildInfoRow(
                      '最低赎回',
                      _formatNumber(_parseDouble(current['min_redeem_unit'])),
                    ),
                    _buildInfoRow('本金', _formatNumber(displayPrincipal)),
                    _buildInfoRow('净值', _formatNav(nav)),
                    _buildInfoRow('份额', _formatNumber(shares)),
                    _buildInfoRow('市值', _formatNumber(displayMarketValue)),
                    _buildInfoRow(
                      '收益率',
                      yieldRate == null ? '-' : _formatPercent(yieldRate),
                    ),
                    _buildInfoRow(
                      '年化收益',
                      annualizedYield == null
                          ? '-'
                          : _formatPercent(annualizedYield),
                    ),
                    _buildInfoRow(
                        '开始日期', (current['start_date'] ?? '').toString()),
                    _buildInfoRow('到期日', (current['end_date'] ?? '').toString()),
                    _buildInfoRow('状态', (current['status'] ?? '').toString()),
                    _buildInfoRow('备注', (current['remark'] ?? '').toString()),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () async {
                          final ok = await _buyProduct(current);
                          if (ok) {
                            await refreshDetail();
                          }
                        },
                        child: const Text('买入'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () async {
                          final ok = await _redeemProduct(current);
                          if (ok) {
                            await refreshDetail();
                          }
                        },
                        child: const Text('赎回'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () async {
                          final ok = await _recordDividend(current);
                          if (ok) {
                            await refreshDetail();
                          }
                        },
                        child: const Text('分红'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () async {
                          final ok = await _showProductDialog(product: current);
                          if (ok) {
                            await refreshDetail();
                          }
                        },
                        child: const Text('编辑'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteProduct(current);
                        },
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _showProductDialog({Map<String, dynamic>? product}) async {
    final accounts = await ApiClient.getAccounts();
    if (!mounted) return false;
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
    final navController = TextEditingController(
      text: _formatNav(_parseDouble(product?['nav'])),
    );
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

                    final riskLevelText = riskController.text.trim();
                    final params = {
                      'account_id': selectedAccountId,
                      'product_name': nameController.text.trim(),
                      'product_code': codeController.text.trim(),
                      'type': typeController.text.trim(),
                      'currency': currencyController.text.trim().isEmpty
                          ? 'CNY'
                          : currencyController.text.trim(),
                      'is_nav_based': isNavBased,
                      'risk_level':
                          riskLevelText.isEmpty ? null : riskLevelText,
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
                    final dialogContext = context;
                    final navigator = Navigator.of(dialogContext);
                    if (response.containsKey('error')) {
                      showErrorSnackBar(dialogContext, response['error']);
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
      return true;
    }
    return false;
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

    if (!mounted) return;
    final safeContext = context;
    final response = await ApiClient.operate(
      'financial_product_delete',
      {'id': product['id']},
    );
    if (!safeContext.mounted) return;
    if (response.containsKey('error')) {
      showErrorSnackBar(safeContext, response['error']);
      return;
    }

    await _refresh();
  }

  Future<bool> _buyProduct(Map<String, dynamic> product) async {
    final isNavProduct = _isNavProduct(product);
    final amountController = TextEditingController();
    final navController = TextEditingController(
      text: _formatNav(_parseDouble(product['nav'])),
    );
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
      return false;
    }

    final accountId = product['account_id'];
    if (accountId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该产品缺少所属账户')),
      );
      return false;
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
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      showErrorSnackBar(context, response['error']);
      return false;
    }

    messenger.showSnackBar(const SnackBar(content: Text('买入成功')));
    await _refresh();
    return true;
  }

  Future<bool> _redeemProduct(Map<String, dynamic> product) async {
    final isNavProduct = _isNavProduct(product);
    final sharesController =
        TextEditingController(text: product['shares']?.toString() ?? '');
    final navController = TextEditingController(
      text: _formatNav(_parseDouble(product['nav'])),
    );
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
      return false;
    }

    final accountId = product['account_id'];
    if (accountId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该产品缺少所属账户')),
      );
      return false;
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
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      showErrorSnackBar(context, response['error']);
      return false;
    }

    messenger.showSnackBar(const SnackBar(content: Text('赎回成功')));
    await _refresh();
    return true;
  }

  Future<bool> _recordDividend(Map<String, dynamic> product) async {
    final amountController = TextEditingController();
    final feeController = TextEditingController();
    final dateController = TextEditingController(text: _today());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('记录理财分红'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '分红金额',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '手续费（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: '分红日期 (YYYY-MM-DD)',
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
                final feeText = feeController.text.trim();
                final fee = feeText.isEmpty ? 0 : double.tryParse(feeText);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的分红金额')),
                  );
                  return;
                }
                if (fee == null || fee < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的手续费')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('记录'),
            ),
          ],
        );
      },
    );

    final amount = double.tryParse(amountController.text);
    final feeText = feeController.text.trim();
    final fee = feeText.isEmpty ? 0 : double.tryParse(feeText);
    final date = dateController.text.trim();
    amountController.dispose();
    feeController.dispose();
    dateController.dispose();

    if (confirmed != true || amount == null || fee == null) {
      return false;
    }

    final accountId = product['account_id'];
    if (accountId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该产品缺少所属账户')),
      );
      return false;
    }

    final response = await ApiClient.operate('financial_dividend', {
      'product_id': product['id'],
      'account_id': accountId,
      'amount': amount,
      'fee': fee,
      'date': date,
      'currency': product['currency'] ?? 'CNY',
    });
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      showErrorSnackBar(context, response['error']);
      return false;
    }

    messenger.showSnackBar(const SnackBar(content: Text('分红已记录')));
    await _refresh();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_FinancialProductsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('加载失败: ${formatApiError(snapshot.error!)}'),
            );
          }
          final data = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '理财产品',
                        style: AppTextStyles.pageTitle,
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
                child: data.products.isEmpty
                    ? const Center(child: Text('暂无理财产品'))
                    : _buildList(data),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(_FinancialProductsData d) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final row in d.products) {
      final m = row as Map<String, dynamic>;
      final id = (m['account_id'] as num?)?.toInt();
      final name = d.accountNames[id] ?? '未知账户';

      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(m);
    }

    final accountNames = grouped.keys.toList()..sort();

    double? displayMarketValueFor(Map<String, dynamic> m) {
      final isNavProduct = _isNavProduct(m);
      final shares = _parseDouble(m['shares']);
      final nav = _parseDouble(m['nav']);
      final marketValueCny = _parseDouble(m['market_value_cny']);
      double? marketValue;
      if (isNavProduct) {
        if (shares != null && nav != null) {
          marketValue = shares * nav;
        }
      } else {
        if (shares != null) {
          marketValue = shares;
        }
      }
      return marketValueCny ?? marketValue;
    }

    int compareItems(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aDate = _parseDate(a['end_date']);
      final bDate = _parseDate(b['end_date']);
      final aHasDate = aDate != null;
      final bHasDate = bDate != null;
      if (aHasDate != bHasDate) {
        return aHasDate ? 1 : -1;
      }
      if (aHasDate && bHasDate) {
        final dateCompare = aDate.compareTo(bDate);
        if (dateCompare != 0) return dateCompare;
      }
      final aYield = _parseDouble(a['annualized_yield']) ?? double.negativeInfinity;
      final bYield = _parseDouble(b['annualized_yield']) ?? double.negativeInfinity;
      return aYield.compareTo(bYield);
    }

    return ListView(
      children: accountNames.map((name) {
        final items = grouped[name]!;
        items.sort(compareItems);
        double totalMarketValue = 0;
        bool hasTotal = false;
        for (final item in items) {
          final value = displayMarketValueFor(item);
          if (value != null) {
            totalMarketValue += value;
            hasTotal = true;
          }
        }
        return ExpansionTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              if (hasTotal)
                Text(
                  _formatNumber(totalMarketValue),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          children: items.map((m) {
            final principal = _parseDouble(m['principal']);
            final principalCny = _parseDouble(m['principal_cny']);
            final displayMarketValue = displayMarketValueFor(m);
            final displayPrincipal = principalCny ?? principal;
            final yieldRate =
                (displayMarketValue != null && displayPrincipal != null && displayPrincipal > 0)
                    ? (displayMarketValue - displayPrincipal) / displayPrincipal
                : null;
            final annualizedYield = _parseDouble(m['annualized_yield']);
            final endDate = (m['end_date'] ?? '').toString().trim();
            final maturityText = '到期 ${endDate.isEmpty ? '-' : endDate}';

            return ListTile(
              title: Text(m['product_name'] ?? '理财产品'),
              subtitle: Text(
                [
                  if (displayMarketValue != null)
                    '市值 ${_formatNumber(displayMarketValue)}',
                  '收益率 ${yieldRate == null ? '-' : _formatPercent(yieldRate)}',
                  '年化 ${annualizedYield == null ? '-' : _formatPercent(annualizedYield)}',
                  maturityText,
                ].join(' · '),
              ),
              onTap: () => _showProductDetail(m),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

/// Wraps loaded products and account name lookup.
class _FinancialProductsData {
  final List<dynamic> products;
  final Map<int, String> accountNames;

  _FinancialProductsData({
    required this.products,
    required this.accountNames,
  });
}
