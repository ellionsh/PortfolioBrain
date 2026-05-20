import 'package:flutter/material.dart';

import '../utils/error_format.dart';
import '../api/api_client.dart';

class CashflowPage extends StatefulWidget {
  const CashflowPage({super.key});

  @override
  State<CashflowPage> createState() => _CashflowPageState();
}

class _CashflowPageState extends State<CashflowPage> {
  late Future<_CashflowData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CashflowData> _load() async {
    final cashflows = await ApiClient.getCashflows();
    final accounts = await ApiClient.getAccounts();

    final Map<int, String> accountNames = {};
    for (final row in accounts) {
      final m = row as Map<String, dynamic>;
      final id = (m['id'] as num).toInt();
      final name = m['name'] as String? ?? '未命名账户';
      accountNames[id] = name;
    }

    return _CashflowData(
      cashflows: cashflows,
      accountNames: accountNames,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_CashflowData>(
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
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('暂无数据'));
          }
          final rawData = data.cashflows;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final rows = rawData
              .whereType<Map<String, dynamic>>()
              .where((row) {
                final dateStr = row['date'];
                if (dateStr == null) return false;
                final date = DateTime.tryParse(dateStr.toString());
                if (date == null) return false;
                final dateOnly = DateTime(date.year, date.month, date.day);
                return !dateOnly.isBefore(today);
              })
              .toList()
            ..sort((a, b) {
              final aDate = DateTime.tryParse(a['date'].toString());
              final bDate = DateTime.tryParse(b['date'].toString());
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return aDate.compareTo(bDate);
            });
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i] as Map<String, dynamic>;
              final amt = row['amount'];
              final dir = row['direction'];
              final color = dir == 'inflow' ? Colors.green : Colors.red;
              final accountId = (row['account_id'] as num?)?.toInt();
              final accountName = accountId == null
                  ? '未知账户'
                  : (data.accountNames[accountId] ?? '账户 $accountId');
              return ListTile(
                title: Text('${row['date']}  ·  ${row['description'] ?? ''}'),
                subtitle: Text('账户 $accountName  ·  来源 ${row['source_type']}'),
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

class _CashflowData {
  final List<dynamic> cashflows;
  final Map<int, String> accountNames;

  const _CashflowData({
    required this.cashflows,
    required this.accountNames,
  });
}
