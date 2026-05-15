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
    final principalController =
        TextEditingController(text: fund?['principal']?.toString() ?? '');
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
                  controller: principalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '成本'),
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
                  'principal':
                      double.tryParse(principalController.text) ?? 0,
                  'status': statusController.text.trim().isEmpty
                      ? 'active'
                      : statusController.text.trim(),
                  'remark': remarkController.text.trim(),
                };

                final action = isNew ? 'fund_product_create' : 'fund_product_update';
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
      messenger.showSnackBar(SnackBar(content: Text(response['error'].toString())));
      return;
    }

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
                  ElevatedButton.icon(
                    onPressed: () => _showFundDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('新增'),
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
                        return ListTile(
                          title: Text(row['fund_name'] ?? '基金产品'),
                          subtitle: Text(
                            '${row['fund_code'] ?? ''} · 份额 ${row['shares'] ?? ''} · 成本 ${row['principal'] ?? ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showFundDialog(fund: row),
                                label: const Text('编辑'),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () => _deleteFund(row),
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
    );
  }
}
