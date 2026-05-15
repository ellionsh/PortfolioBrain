import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/api_server_config.dart';

import 'pages/home_page.dart';
import 'pages/accounts_page.dart';
import 'pages/cashflow_page.dart';
import 'pages/investments_page.dart';
import 'pages/agent_chat_page.dart';
import 'pages/server_config_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await ApiServerConfig.load();

  ApiClient.configure(
    host: config.host,
    port: config.port,
    scheme: config.scheme,
  );

  runApp(
    PortfolioBrainApp(initialConfig: config),
  );
}

class PortfolioBrainApp extends StatefulWidget {
  final ApiServerConfig initialConfig;

  const PortfolioBrainApp({
    super.key,
    required this.initialConfig,
  });

  @override
  State<PortfolioBrainApp> createState() => _PortfolioBrainAppState();
}

class _PortfolioBrainAppState extends State<PortfolioBrainApp> {
  int _index = 0;

  late ApiServerConfig _config;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _config = widget.initialConfig;

    _pages = [
      const HomePage(),
      const AccountsPage(),
      const InvestmentsPage(),
      const CashflowPage(),
      const AgentChatPage(),
    ];
  }

  void _applyConfig(ApiServerConfig config) {
    ApiClient.configure(
      host: config.host,
      port: config.port,
      scheme: config.scheme,
    );

    setState(() {
      _config = config;
      _index = 0;
    });
  }

  Future<void> _openServerConfig(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ServerConfigPage(
          initialConfig: _config,
          canCancel: true,
          onSaved: (config) {
            _applyConfig(config);

            // 关闭配置页面
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'PortfolioBrain',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),

      home: _config.isConfigured
        ? Builder(
            builder: (context) {
              return Scaffold(
                  appBar: AppBar(
                    title: const Text('PortfolioBrain'),

                    actions: [
                      IconButton(
                        tooltip: '服务器配置',
                        onPressed: () => _openServerConfig(context),
                        icon: const Icon(Icons.settings_ethernet_rounded),
                      ),
                    ],
                  ),

                  // 保持页面状态
                  body: IndexedStack(
                    index: _index,
                    children: _pages,
                  ),

                  // Material 3 NavigationBar
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: _index,

                    onDestinationSelected: (i) {
                      setState(() {
                        _index = i;
                      });
                    },

                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_rounded),
                        label: '首页',
                      ),

                      NavigationDestination(
                        icon: Icon(Icons.account_balance_wallet_rounded),
                        label: '账户',
                      ),

                      NavigationDestination(
                        icon: Icon(Icons.trending_up_rounded),
                        label: '资产',
                      ),

                      NavigationDestination(
                        icon: Icon(Icons.swap_horiz_rounded),
                        label: '现金流',
                      ),

                      NavigationDestination(
                        icon: Icon(Icons.smart_toy_rounded),
                        label: 'AI',
                      ),
                    ],
                  ),
              );
            },
          )            
          : ServerConfigPage(
              initialConfig: _config,
              onSaved: _applyConfig,
            ),
    );
  }
}

