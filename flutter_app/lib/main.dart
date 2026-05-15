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
  runApp(PortfolioBrainApp(initialConfig: config));
}

class PortfolioBrainApp extends StatefulWidget {
  final ApiServerConfig initialConfig;

  const PortfolioBrainApp({super.key, required this.initialConfig});

  @override
  State<PortfolioBrainApp> createState() => _PortfolioBrainAppState();
}

class _PortfolioBrainAppState extends State<PortfolioBrainApp> {
  int _index = 0;
  int _configVersion = 0;
  late ApiServerConfig _config;

  final _pages = const [
    HomePage(),
    AccountsPage(),
    InvestmentsPage(),
    CashflowPage(),
    AgentChatPage(),
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  void _applyConfig(ApiServerConfig config) {
    ApiClient.configure(
      host: config.host,
      port: config.port,
      scheme: config.scheme,
    );
    setState(() {
      _config = config;
      _configVersion++;
      _index = 0;
    });
  }

  Future<void> _openServerConfig() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ServerConfigPage(
          initialConfig: _config,
          canCancel: true,
          onSaved: (config) {
            _applyConfig(config);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PortfolioBrain',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _config.isConfigured
          ? Scaffold(
              body: Stack(
                children: [
                  KeyedSubtree(
                    key: ValueKey('$_configVersion-$_index'),
                    child: _pages[_index],
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: SafeArea(
                      child: IconButton.filledTonal(
                        tooltip: '服务器配置',
                        onPressed: _openServerConfig,
                        icon: const Icon(Icons.settings_ethernet),
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _index,
                type: BottomNavigationBarType.fixed,
                onTap: (i) => setState(() => _index = i),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: '首页',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_wallet),
                    label: '账户',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inventory_2),
                    label: '资产',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long),
                    label: '现金流',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.smart_toy),
                    label: '助手',
                  ),
                ],
              ),
            )
          : ServerConfigPage(
              initialConfig: _config,
              onSaved: _applyConfig,
            ),
    );
  }
}

