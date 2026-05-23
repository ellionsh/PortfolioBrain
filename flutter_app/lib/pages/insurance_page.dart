import 'package:flutter/material.dart';

import '../utils/error_format.dart';
import '../api/api_client.dart';
import '../theme/app_text_styles.dart';

class InsurancePage extends StatefulWidget {
  const InsurancePage({super.key});

  @override
  State<InsurancePage> createState() => _InsurancePageState();
}

class _InsurancePageState extends State<InsurancePage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getInsurance();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ApiClient.getInsurance();
    });
  }

  Future<void> _showInsuranceDialog({Map<String, dynamic>? insurance}) async {
    final accounts = await ApiClient.getAccounts();
    if (!mounted) return;
    final accountChoices = accounts
        .cast<Map<String, dynamic>>()
        .map((m) => MapEntry((m['id'] as num).toInt(), m['name'] as String? ?? ''))
        .toList();

    int? selectedAccountId = insurance != null ? (insurance['account_id'] as num?)?.toInt() : null;
    final productNameController = TextEditingController(text: insurance?['product_name'] ?? '');
    final companyController = TextEditingController(text: insurance?['company'] ?? '');
    final typeController = TextEditingController(text: insurance?['type'] ?? '');
    final currencyController = TextEditingController(text: insurance?['currency'] ?? 'CNY');
    final premiumController = TextEditingController(text: insurance?['premium']?.toString() ?? '');
    final premiumFreqController = TextEditingController(text: insurance?['premium_freq'] ?? 'annual');
    final premiumYearsController = TextEditingController(text: insurance?['premium_years']?.toString() ?? '');
    final coverageController = TextEditingController(text: insurance?['coverage_amount']?.toString() ?? '');
    final startController = TextEditingController(text: insurance?['start_date'] ?? '');
    final endController = TextEditingController(text: insurance?['end_date'] ?? '');
    final cashValueController = TextEditingController(text: insurance?['cash_value']?.toString() ?? '');
    final statusController = TextEditingController(text: insurance?['status'] ?? 'active');
    final remarkController = TextEditingController(text: insurance?['remark'] ?? '');

    final isNew = insurance == null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? '新增保险产品' : '编辑保险产品'),
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
                  controller: productNameController,
                  decoration: const InputDecoration(labelText: '产品名称'),
                ),
                TextField(
                  controller: companyController,
                  decoration: const InputDecoration(labelText: '保险公司'),
                ),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(labelText: '类型'),
                ),
                TextField(
                  controller: currencyController,
                  decoration: const InputDecoration(labelText: '币种'),
                ),
                TextField(
                  controller: premiumController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '保费'),
                ),
                TextField(
                  controller: premiumFreqController,
                  decoration: const InputDecoration(labelText: '保费周期'),
                ),
                TextField(
                  controller: premiumYearsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '缴费年限'),
                ),
                TextField(
                  controller: coverageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '保额'),
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
                  controller: cashValueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '现金价值'),
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
                if (selectedAccountId == null || productNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写产品名称和所属账户')));
                  return;
                }

                final params = {
                  'account_id': selectedAccountId,
                  'product_name': productNameController.text.trim(),
                  'company': companyController.text.trim(),
                  'type': typeController.text.trim(),
                  'currency': currencyController.text.trim().isEmpty ? 'CNY' : currencyController.text.trim(),
                  'premium': double.tryParse(premiumController.text) ?? 0,
                  'premium_freq': premiumFreqController.text.trim(),
                  'premium_years': int.tryParse(premiumYearsController.text) ?? 0,
                  'coverage_amount': double.tryParse(coverageController.text) ?? 0,
                  'start_date': startController.text.trim(),
                  'end_date': endController.text.trim(),
                  'cash_value': double.tryParse(cashValueController.text) ?? 0,
                  'status': statusController.text.trim().isEmpty ? 'active' : statusController.text.trim(),
                  'remark': remarkController.text.trim(),
                };

                final action = isNew ? 'insurance_create' : 'insurance_update';
                if (!isNew) {
                  params['id'] = insurance['id'];
                }

                final response = await ApiClient.operate(action, params);
                if (!context.mounted) return;
                final navigatorContext = this.context;
                final messenger = ScaffoldMessenger.of(navigatorContext);
                final navigator = Navigator.of(navigatorContext);
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

  Future<void> _deleteInsurance(Map<String, dynamic> insurance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除保险产品'),
          content: Text('确认删除保险产品 ${insurance['product_name'] ?? ''} 吗？'),
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

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final response =
        await ApiClient.operate('insurance_delete', {'id': insurance['id']});
    if (!context.mounted) return;
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
            return Center(
              child: Text('加载失败: ${formatApiError(snapshot.error!)}'),
            );
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
                        '保险产品',
                        style: AppTextStyles.pageTitle,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => _showInsuranceDialog(),
                      tooltip: '新增',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: data.isEmpty
                    ? const Center(child: Text('暂无保险产品'))
                    : ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, i) {
                          final row = data[i] as Map<String, dynamic>;
                          return ListTile(
                            title: Text(row['product_name'] ?? '保险产品'),
                            subtitle: Text('${row['company'] ?? ''} · 保费 ${row['premium'] ?? ''} · ${row['premium_freq'] ?? ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _showInsuranceDialog(insurance: row),
                                  tooltip: '编辑',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _deleteInsurance(row),
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
