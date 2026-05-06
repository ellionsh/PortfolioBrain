import 'package:flutter/material.dart';
import '../api/api_client.dart';

class CashflowPage extends StatefulWidget {
  const CashflowPage({super.key});

  @override
  State<CashflowPage> createState() => _CashflowPageState();
}

class _CashflowPageState extends State<CashflowPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getCashflows();
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
              final amt = row['amount'];
              final dir = row['direction'];
              final color = dir == 'inflow' ? Colors.green : Colors.red;
              return ListTile(
                title: Text('${row['date']}  ·  ${row['description'] ?? ''}'),
                subtitle: Text('账户 ${row['account_id']}  ·  来源 ${row['source_type']}'),
                trailing: Text(
                  amt.toString(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
