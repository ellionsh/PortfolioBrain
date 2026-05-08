import 'package:flutter/material.dart';
import '../api/api_client.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getAccounts();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ApiClient.getAccounts();
    });
  }

  Future<void> _showAccountDialog({Map<String, dynamic>? account}) async {
    final nameController = TextEditingController(text: account?['name'] ?? '');
    final institutionController = TextEditingController(text: account?['institution'] ?? '');
    final typeController = TextEditingController(text: account?['type'] ?? '');
    final currencyController = TextEditingController(text: account?['currency'] ?? 'CNY');

    final isNew = account == null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? '新增账户' : '编辑账户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '账户名称'),
                ),
                TextField(
                  controller: institutionController,
                  decoration: const InputDecoration(labelText: '机构名称'),
                ),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(labelText: '账户类型'),
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
                final name = nameController.text.trim();
                final institution = institutionController.text.trim();
                final type = typeController.text.trim();
                final currency = currencyController.text.trim().isEmpty ? 'CNY' : currencyController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('账户名称不能为空')));
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final action = isNew ? 'account_create' : 'account_update';
                final params = {
                  'name': name,
                  'institution': institution,
                  'type': type,
                  'currency': currency,
                };
                if (!isNew) {
                  params['id'] = account['id']?.toString()?? '';
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

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除账户'),
          content: Text('确认删除账户 ${account['name'] ?? '未知'} 吗？'),
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

    final response = await ApiClient.operate('account_delete', {'id': account['id']?.toString() ?? ''});
    if (!mounted) return;
    if (response.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['error'].toString())));
      return;
    }

    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '账户列表',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAccountDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('新增'),
                ),
              ],
            ),
          ),
          Expanded(
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
                if (data.isEmpty) {
                  return const Center(child: Text('暂无账户数据'));
                }
                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final row = data[i] as Map<String, dynamic>;
                    return ListTile(
                      title: Text(row['name'] ?? '未命名账户'),
                      subtitle: Text('${row['institution'] ?? ''}  ·  ${row['type'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(row['currency'] ?? 'CNY'),
                          ElevatedButton.icon(
                            onPressed: () => _showAccountDialog(account: row),
                            icon: const Icon(Icons.edit, size: 20),
                            label: const Text('编辑'),
                          ),

                          ElevatedButton.icon(
                            onPressed: () => _deleteAccount(row),
                            icon: const Icon(Icons.delete, size: 20),
                            label: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
