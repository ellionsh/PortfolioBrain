import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../utils/error_format.dart';

import '../api/api_client.dart';
import '../theme/app_text_styles.dart';

class FundProductsPage extends StatefulWidget {
  const FundProductsPage({super.key});

  @override
  State<FundProductsPage> createState() => _FundProductsPageState();
}

class _FundProductsPageState extends State<FundProductsPage> {
  late Future<_FundProductsData> _future;

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

  Future<_FundProductsData> _load() async {
    final accounts = await ApiClient.getAccounts();
    final products = await ApiClient.getFundProducts();

    final Map<int, String> accountNames = {};
    for (final row in accounts) {
      final m = row as Map<String, dynamic>;
      final id = (m['id'] as num).toInt();
      final name = m['name'] as String? ?? '未命名账户';
      accountNames[id] = name;
    }

    return _FundProductsData(
      products: products,
      accountNames: accountNames,
    );
  }

  Future<Map<String, dynamic>?> _fetchFundById(int id) async {
    final products = await ApiClient.getFundProducts();
    for (final row in products) {
      final m = row as Map<String, dynamic>;
      if ((m['id'] as num?)?.toInt() == id) {
        return m;
      }
    }
    return null;
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

  String _formatNav(double? value) => _formatNumber(value, fraction: 4);

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

  Future<void> _showFundDetail(Map<String, dynamic> fund) async {
    Map<String, dynamic> current = Map<String, dynamic>.from(fund);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> refreshDetail() async {
              final id = (current['id'] as num?)?.toInt();
              if (id == null) return;
              final latest = await _fetchFundById(id);
              if (!mounted || latest == null) return;
              setDialogState(() {
                current = latest;
              });
            }

            final shares = _parseDouble(current['shares']);
            final nav = _parseDouble(current['nav']);
            final principal = _parseDouble(current['principal']);
            final principalCny = _parseDouble(current['principal_cny']);
            final marketValueCny = _parseDouble(current['market_value_cny']);
            final marketValue = (shares != null && nav != null) ? shares * nav : null;
            final displayMarketValue = marketValueCny ?? marketValue;
            final displayPrincipal = principalCny ?? principal;
            final yieldRate =
                (displayMarketValue != null &&
                        displayPrincipal != null &&
                        displayPrincipal > 0)
                    ? (displayMarketValue - displayPrincipal) / displayPrincipal
                    : null;
            final startDate = _parseDate(current['start_date']);
            double? annualizedYield;
            if (yieldRate != null && startDate != null && yieldRate > -1) {
              final days = DateTime.now().difference(startDate).inDays;
              if (days > 0) {
                annualizedYield = math.pow(1 + yieldRate, 365 / days) - 1;
              }
            }

            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              title: Text(current['fund_name'] ?? '基金详情'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _buildInfoRow('基金代码', (current['fund_code'] ?? '').toString()),
                    _buildInfoRow('币种', (current['currency'] ?? '').toString()),
                    _buildInfoRow('成本', _formatNumber(displayPrincipal)),
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
                          final ok = await _buyFund(current);
                          if (ok) {
                            await refreshDetail();
                          }
                        },
                        child: const Text('买入'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () async {
                          final ok = await _redeemFund(current);
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
                          final ok = await _showFundDialog(fund: current);
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
                          _deleteFund(current);
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

  Future<bool> _showFundDialog({Map<String, dynamic>? fund}) async {
    final accounts = await ApiClient.getAccounts();
    if (!mounted) return false;
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
    Timer? debounceTimer;
    String lastQuery = '';
    String? previewName;
    double? previewNav;
    String? previewDate;
    String? previewError;
    bool previewLoading = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> fetchPreview(String code) async {
              final trimmed = code.trim();
              lastQuery = trimmed;
              debounceTimer?.cancel();
              if (trimmed.isEmpty) {
                setDialogState(() {
                  previewName = null;
                  previewNav = null;
                  previewDate = null;
                  previewError = null;
                  previewLoading = false;
                });
                return;
              }
              debounceTimer = Timer(const Duration(milliseconds: 500), () async {
                setDialogState(() {
                  previewLoading = true;
                  previewError = null;
                });
                try {
                  final info = await ApiClient.getFundMeta(trimmed);
                  if (lastQuery != trimmed) return;
                  setDialogState(() {
                    previewName = info['fund_name']?.toString();
                    previewNav = _parseDouble(info['nav']);
                    previewDate = info['nav_date']?.toString();
                    previewError = info['error']?.toString();
                    previewLoading = false;
                  });
                } catch (e) {
                  if (lastQuery != trimmed) return;
                  setDialogState(() {
                    previewError = formatApiError(e);
                    previewLoading = false;
                  });
                }
              });
            }

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
                      controller: codeController,
                      decoration: const InputDecoration(labelText: '基金代码'),
                      onChanged: isNew ? fetchPreview : null,
                    ),
                    if (isNew)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '基金名称与净值将自动从 AkShare 获取',
                          style: AppTextStyles.hint.copyWith(color: Colors.black54),
                        ),
                      ),
                    if (isNew)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Builder(
                          builder: (context) {
                            if (previewLoading) {
                              return Row(
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text('正在获取基金信息...'),
                                ],
                              );
                            }
                            if (previewError != null) {
                              return Text(
                                previewError!,
                                style: AppTextStyles.hint.copyWith(color: Colors.redAccent),
                              );
                            }
                            if (previewName == null && previewNav == null) {
                              return const SizedBox.shrink();
                            }
                            final navText =
                                previewNav == null ? '-' : _formatNav(previewNav);
                            final dateText = (previewDate ?? '').trim();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('基金名称：${previewName ?? '-'}'),
                                Text(
                                  '基金净值：$navText'
                                  '${dateText.isEmpty ? '' : '（$dateText）'}',
                                ),
                              ],
                            );
                          },
                        ),
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
                    if (!isNew)
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
                      decoration: const InputDecoration(
                          labelText: '开始日期 (YYYY-MM-DD)'),
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
                    if (!isNew)
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '基金名称'),
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
                final fundCode = codeController.text.trim();
                final fundName = nameController.text.trim();
                if (selectedAccountId == null ||
                    fundCode.isEmpty ||
                    (!isNew && fundName.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isNew ? '请填写基金代码和所属账户' : '请填写基金名称、代码和所属账户',
                      ),
                    ),
                  );
                  return;
                }

                final params = <String, dynamic>{
                  'account_id': selectedAccountId,
                  'fund_code': fundCode,
                  'currency': currencyController.text.trim().isEmpty
                      ? 'CNY'
                      : currencyController.text.trim(),
                  'shares': double.tryParse(sharesController.text) ?? 0,
                  'principal': double.tryParse(principalController.text) ?? 0,
                  'start_date': startController.text.trim(),
                  'end_date': endController.text.trim(),
                  'status': statusController.text.trim().isEmpty
                      ? 'active'
                      : statusController.text.trim(),
                  'remark': remarkController.text.trim(),
                };
                if (!isNew) {
                  params.addAll({
                    'fund_name': fundName,
                    'nav': double.tryParse(navController.text),
                  });
                }

                final action =
                    isNew ? 'fund_product_create' : 'fund_product_update';
                if (!isNew) {
                  params['id'] = fund['id'];
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

    debounceTimer?.cancel();
    if (result == true) {
      await _refresh();
      return true;
    }
    return false;
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

    if (!mounted) return;
    final safeContext = context;
    final response =
        await ApiClient.operate('fund_product_delete', {'id': fund['id']});
    if (!safeContext.mounted) return;
    if (response.containsKey('error')) {
      showErrorSnackBar(safeContext, response['error']);
      return;
    }

    await _refresh();
  }

  Future<bool> _buyFund(Map<String, dynamic> fund) async {
    final amountController = TextEditingController();
    final sharesController = TextEditingController();
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
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '买入份额（可选）',
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
                final sharesText = sharesController.text.trim();
                final shares =
                    sharesText.isEmpty ? null : double.tryParse(sharesText);
                if (amount == null || amount <= 0 || nav == null || nav <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的买入金额和净值')),
                  );
                  return;
                }
                if (sharesText.isNotEmpty && (shares == null || shares <= 0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的买入份额')),
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
    final sharesText = sharesController.text.trim();
    final shares = sharesText.isEmpty ? null : double.tryParse(sharesText);
    final nav = double.tryParse(navController.text);
    final date = dateController.text.trim();
    amountController.dispose();
    sharesController.dispose();
    navController.dispose();
    dateController.dispose();

    if (confirmed != true || amount == null || nav == null) {
      return false;
    }

    final accountId = fund['account_id'];
    if (accountId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该基金缺少所属账户')),
      );
      return false;
    }

    final request = <String, dynamic>{
      'fund_id': fund['id'],
      'account_id': accountId,
      'amount': amount,
      'nav': nav,
      'date': date,
    };
    if (shares != null) {
      request['shares'] = shares;
    }
    final response = await ApiClient.operate('fund_buy', request);
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

  Future<bool> _redeemFund(Map<String, dynamic> fund) async {
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
      return false;
    }

    final accountId = fund['account_id'];
    if (accountId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该基金缺少所属账户')),
      );
      return false;
    }

    final response = await ApiClient.operate('fund_sell', {
      'fund_id': fund['id'],
      'account_id': accountId,
      'shares': shares,
      'nav': nav,
      'date': date,
    });
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      messenger.showSnackBar(
        SnackBar(content: Text(response['error'].toString())),
      );
      return false;
    }

    messenger.showSnackBar(const SnackBar(content: Text('赎回成功')));
    await _refresh();
    return true;
  }

  Future<bool> _recordDividend(Map<String, dynamic> fund) async {
    final amountController = TextEditingController();
    final feeController = TextEditingController();
    final dateController = TextEditingController(text: _today());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('记录基金分红'),
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

    final accountId = fund['account_id'];
    if (accountId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该基金缺少所属账户')),
      );
      return false;
    }

    final response = await ApiClient.operate('fund_dividend', {
      'fund_id': fund['id'],
      'account_id': accountId,
      'amount': amount,
      'fee': fee,
      'date': date,
      'currency': fund['currency'] ?? 'CNY',
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
    return FutureBuilder<_FundProductsData>(
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
                        '基金产品',
                        style: AppTextStyles.pageTitle,
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
              child: data.products.isEmpty
                  ? const Center(child: Text('暂无基金产品'))
                  : _buildList(data),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(_FundProductsData data) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final row in data.products) {
      final m = row as Map<String, dynamic>;
      final id = (m['account_id'] as num?)?.toInt();
      final name = data.accountNames[id] ?? '未知账户';
      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(m);
    }

    final accountNames = grouped.keys.toList()..sort();

    double? displayMarketValueFor(Map<String, dynamic> row) {
      final shares = _parseDouble(row['shares']);
      final nav = _parseDouble(row['nav']);
      final marketValueCny = _parseDouble(row['market_value_cny']);
      final marketValue = (shares != null && nav != null) ? shares * nav : null;
      return marketValueCny ?? marketValue;
    }

    double? annualizedYieldFor(Map<String, dynamic> row) {
      final principal = _parseDouble(row['principal']);
      final principalCny = _parseDouble(row['principal_cny']);
      final displayMarketValue = displayMarketValueFor(row);
      final displayPrincipal = principalCny ?? principal;
      final yieldRate =
          (displayMarketValue != null &&
                  displayPrincipal != null &&
                  displayPrincipal > 0)
              ? (displayMarketValue - displayPrincipal) / displayPrincipal
              : null;
      final startDate = _parseDate(row['start_date']);
      if (yieldRate != null && startDate != null && yieldRate > -1) {
        final days = DateTime.now().difference(startDate).inDays;
        if (days > 0) {
          return math.pow(1 + yieldRate, 365 / days) - 1;
        }
      }
      return null;
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
      final aYield = annualizedYieldFor(a) ?? double.negativeInfinity;
      final bYield = annualizedYieldFor(b) ?? double.negativeInfinity;
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
          children: items.map((row) {
            final principal = _parseDouble(row['principal']);
            final principalCny = _parseDouble(row['principal_cny']);
            final displayMarketValue = displayMarketValueFor(row);
            final displayPrincipal = principalCny ?? principal;
            final yieldRate =
                (displayMarketValue != null &&
                        displayPrincipal != null &&
                        displayPrincipal > 0)
                    ? (displayMarketValue - displayPrincipal) / displayPrincipal
                    : null;
            final startDate = _parseDate(row['start_date']);
            double? annualizedYield;
            if (yieldRate != null && startDate != null && yieldRate > -1) {
              final days = DateTime.now().difference(startDate).inDays;
              if (days > 0) {
                annualizedYield = math.pow(1 + yieldRate, 365 / days) - 1;
              }
            }
            final endDate = (row['end_date'] ?? '').toString().trim();
            final maturityText = '到期 ${endDate.isEmpty ? '-' : endDate}';

            return ListTile(
              title: Text(row['fund_name'] ?? '基金产品'),
              subtitle: Text(
                [
                  if (displayMarketValue != null)
                    '市值 ${_formatNumber(displayMarketValue)}',
                  '收益率 ${yieldRate == null ? '-' : _formatPercent(yieldRate)}',
                  '年化 ${annualizedYield == null ? '-' : _formatPercent(annualizedYield)}',
                  maturityText,
                ].join(' · '),
              ),
              onTap: () => _showFundDetail(row),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _FundProductsData {
  final List<dynamic> products;
  final Map<int, String> accountNames;

  _FundProductsData({
    required this.products,
    required this.accountNames,
  });
}
