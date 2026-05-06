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
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, i) {
              final row = data[i] as Map<String, dynamic>;
              return ListTile(
                title: Text(row['name'] ?? '未命名账户'),
                subtitle: Text('${row['institution'] ?? ''}  ·  ${row['type'] ?? ''}'),
                trailing: Text(row['currency'] ?? 'CNY'),
              );
            },
          );
        },
      ),
    );
  }
}
