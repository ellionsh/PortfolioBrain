import 'package:flutter/material.dart';
import '../api/api_client.dart';

class DepositsPage extends StatefulWidget {
  const DepositsPage({super.key});

  @override
  State<DepositsPage> createState() => _DepositsPageState();
}

class _DepositsPageState extends State<DepositsPage> {
  late Future<_DepositsData> _future;

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

  Future<_DepositsData> _load() async {
    final accounts = await ApiClient.getAccounts();
    final deposits = await ApiClient.getBankDeposits();

    // 构建 account_id → account_name 映射
    final Map<int, String> accountNames = {};
    for (final row in accounts) {
      final m = row as Map<String, dynamic>;
      final id = (m['id'] as num).toInt();
      final name = m['name'] as String? ?? '未命名账户';
      accountNames[id] = name;
    }

    return _DepositsData(
      deposits: deposits,
      accountNames: accountNames,
    );
  }

  Future<void> _showDepositDialog({Map<String, dynamic>? deposit, required Map<int, String> accountNames}) async {
    final accountChoices = accountNames.entries.toList();

    int? selectedAccountId = deposit != null ? (deposit['account_id'] as num?)?.toInt() : null;
    final typeController = TextEditingController(text: deposit?['deposit_type'] ?? '');
    final principalController = TextEditingController(text: deposit?['principal']?.toString() ?? '');
    final rateController = TextEditingController(text: deposit != null?(((deposit['interest_rate'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(2):'');
    final startController = TextEditingController(text: deposit?['start_date'] ?? '');
    final endController = TextEditingController(text: deposit?['end_date'] ?? '');
    final currencyController = TextEditingController(text: deposit?['currency'] ?? 'CNY');

    final isNew = deposit == null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? '新增银行存款' : '编辑银行存款'),
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
                  controller: typeController,
                  decoration: const InputDecoration(labelText: '存款类型'),
                ),
                TextField(
                  controller: principalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '本金'),
                ),
                TextField(
                  controller: rateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '利率 (%)'),
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
                  controller: currencyController,
                  decoration: const InputDecoration(labelText: '币种'),
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
                if (selectedAccountId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择所属账户')));
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final principal = double.tryParse(principalController.text) ?? 0;
                final rate = (double.tryParse(rateController.text) ?? 0) / 100;
                final params = {
                  'account_id': selectedAccountId,
                  'deposit_type': typeController.text.trim(),
                  'principal': principal,
                  'interest_rate': rate,
                  'start_date': startController.text.trim(),
                  'end_date': endController.text.trim(),
                  'currency': currencyController.text.trim().isEmpty ? 'CNY' : currencyController.text.trim(),
                };

                final action = isNew ? 'bank_deposit_add' : 'bank_deposit_update';
                if (!isNew) {
                  params['id'] = deposit['id'];
                }

                final response = await ApiClient.operate(action, params);
                if (!mounted) return;
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

  Future<void> _deleteDeposit(Map<String, dynamic> deposit) async {
    final dialogContext = context;
    final messenger = ScaffoldMessenger.of(dialogContext);
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除银行存款'),
          content: const Text('确认删除这条银行存款吗？'),
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

    final response = await ApiClient.operate('bank_deposit_delete', {'id': deposit['id']});
    if (response.containsKey('error')) {
      messenger.showSnackBar(SnackBar(content: Text(response['error'].toString())));
      return;
    }

    await _refresh();
  }

  Future<void> _withdrawDeposit(Map<String, dynamic> deposit) async {
    final principal = (deposit['principal'] as num?)?.toDouble() ?? 0;
    final amountController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('取出存款'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('当前本金 ¥${principal.toStringAsFixed(2)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '取出金额',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || amount > principal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写有效的取出金额')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('取出'),
            ),
          ],
        );
      },
    );

    final amount = double.tryParse(amountController.text);
    amountController.dispose();

    if (confirmed != true || amount == null) {
      return;
    }

    final response = await ApiClient.operate('bank_deposit_withdraw', {
      'id': deposit['id'],
      'amount': amount,
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (response.containsKey('error')) {
      messenger.showSnackBar(
        SnackBar(content: Text(response['error'].toString())),
      );
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('取出成功')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_DepositsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
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
                        '资产明细',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => _showDepositDialog(accountNames: data.accountNames),
                      tooltip: '新增',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildList(data)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(_DepositsData d) {
    // 按账户名称分组
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final row in d.deposits) {
      final m = row as Map<String, dynamic>;
      final id = (m['account_id'] as num?)?.toInt();
      final name = d.accountNames[id] ?? '未知账户';

      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(m);
    }

    final accountNames = grouped.keys.toList()..sort();

    return ListView(
      children: accountNames.map((name) {
        final items = grouped[name]!;
        return ExpansionTile(
          title: Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          children: items.map((m) {
            final principal = (m['principal'] as num?)?.toDouble() ?? 0;
            final rate = (m['interest_rate'] as num?)?.toDouble() ?? 0;
            final type = m['deposit_type'] ?? '';
            final start = m['start_date'] ?? '';
            final end = m['end_date'] ?? '';

            return ListTile(
              title: Text('$type · 本金 ¥${principal.toStringAsFixed(2)}'),
              subtitle: Text('利率 ${ (rate * 100).toStringAsFixed(2) }%\n$start ~ $end'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showDepositDialog(deposit: m, accountNames: d.accountNames),
                    tooltip: '编辑',
                  ),
                  IconButton(
                    icon: const Icon(Icons.payments, size: 20),
                    onPressed: () => _withdrawDeposit(m),
                    tooltip: '取出',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _deleteDeposit(m),
                    tooltip: '删除',
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _DepositsData {
  final List<dynamic> deposits;
  final Map<int, String> accountNames;

  _DepositsData({
    required this.deposits,
    required this.accountNames,
  });
}
