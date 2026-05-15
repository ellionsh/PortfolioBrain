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

  Future<void> _showProductDialog({Map<String, dynamic>? product}) async {
    final accounts = await ApiClient.getAccounts();
    if (!mounted) return;
    final accountChoices = accounts
        .cast<Map<String, dynamic>>()
        .map((m) => MapEntry((m['id'] as num).toInt(), m['name'] as String? ?? ''))
        .toList();

    int? selectedAccountId = product != null ? (product['account_id'] as num?)?.toInt() : null;
    final nameController = TextEditingController(text: product?['product_name'] ?? '');
    final codeController = TextEditingController(text: product?['product_code'] ?? '');
    final typeController = TextEditingController(text: product?['type'] ?? '');
    final currencyController = TextEditingController(text: product?['currency'] ?? 'CNY');
    bool isNavBased = product != null ? (product['is_nav_based'] == 1 || product['is_nav_based'] == true) : true;
    final riskController = TextEditingController(text: product?['risk_level']?.toString() ?? '');
    final minRedeemController = TextEditingController(text: product?['min_redeem_unit']?.toString() ?? '');
    final principalController = TextEditingController(text: product?['principal']?.toString() ?? '');
    final expectedYieldController = TextEditingController(text: product?['expected_yield']?.toString() ?? '');
    final startController = TextEditingController(text: product?['start_date'] ?? '');
    final endController = TextEditingController(text: product?['end_date'] ?? '');
    final payFreqController = TextEditingController(text: product?['pay_freq'] ?? '');
    final statusController = TextEditingController(text: product?['status'] ?? 'active');
    final remarkController = TextEditingController(text: product?['remark'] ?? '');

    final isNew = product == null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
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
                  onChanged: (value) => setState(() => isNavBased = value),
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
                  controller: expectedYieldController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '预期收益'),
                ),
                TextField(
                  controller: startController,
                  decoration: const InputDecoration(labelText: '开始日期 (YYYY-MM-DD)'),
                ),
                TextField(
                  controller: endController,
                  decoration: const InputDecoration(labelText: '结束日期 (YYYY-MM-DD)'),
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
                if (selectedAccountId == null || nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写产品名称和所属账户')));
                  return;
                }

                final params = {
                  'account_id': selectedAccountId,
                  'product_name': nameController.text.trim(),
                  'product_code': codeController.text.trim(),
                  'type': typeController.text.trim(),
                  'currency': currencyController.text.trim().isEmpty ? 'CNY' : currencyController.text.trim(),
                  'is_nav_based': isNavBased,
                  'risk_level': int.tryParse(riskController.text),
                  'min_redeem_unit': double.tryParse(minRedeemController.text),
                  'principal': double.tryParse(principalController.text),
                  'expected_yield': double.tryParse(expectedYieldController.text),
                  'start_date': startController.text.trim(),
                  'end_date': endController.text.trim(),
                  'pay_freq': payFreqController.text.trim(),
                  'status': statusController.text.trim().isEmpty ? 'active' : statusController.text.trim(),
                  'remark': remarkController.text.trim(),
                };

                final action = isNew ? 'financial_product_create' : 'financial_product_update';
                if (!isNew) {
                  params['id'] = product['id'];
                }
                final response = await ApiClient.operate(action, params);
                if (!context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                if (response.containsKey('error')) {
                  messenger.showSnackBar(SnackBar(content: Text(response['error'].toString())));
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

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除理财产品'),
          content: Text('确认删除理财产品 ${product['product_name'] ?? ''} 吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final response = await ApiClient.operate('financial_product_delete', {'id': product['id']});
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      messenger.showSnackBar(SnackBar(content: Text(response['error'].toString())));
      return;
    }

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
                    ElevatedButton.icon(
                      onPressed: () => _showProductDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('新增'),
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
                          return ListTile(
                            title: Text(row['product_name'] ?? '理财产品'),
                            subtitle: Text('${row['type'] ?? ''} · ${row['product_code'] ?? ''} · 本金 ${row['principal'] ?? ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _showProductDialog(product: row),
                                  label: const Text('编辑'),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _deleteProduct(row),
                                  label: const Text('删除'),
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
