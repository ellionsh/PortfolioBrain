import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/api_server_config.dart';
import 'api/auth_storage.dart';
import 'api/release_bootstrap.dart';
import 'api/simple_prefs.dart';

import 'pages/home_page.dart';
import 'pages/accounts_page.dart';
import 'pages/cashflow_page.dart';
import 'pages/investments_page.dart';
import 'pages/agent_chat_page.dart';
import 'pages/server_config_page.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ReleaseBootstrap.ensureCleanStart();

  final config = await ApiServerConfig.load();
  final accessToken = await AuthStorage.loadAccessToken();
  final refreshToken = await AuthStorage.loadRefreshToken();
  final themeMode = await _loadThemeMode();

  ApiClient.configure(
    host: config.host,
    port: config.port,
    scheme: config.scheme,
  );
  ApiClient.setTokens(accessToken, refreshToken);

  runApp(
    PortfolioBrainApp(
      initialConfig: config,
      initialToken: accessToken,
      initialRefreshToken: refreshToken,
      initialThemeMode: themeMode,
    ),
  );
}

const _themeModeKey = 'theme_mode';

Future<ThemeMode> _loadThemeMode() async {
  try {
    final value = await SimplePrefs.getString(_themeModeKey);
    if (value is! String) {
      return ThemeMode.system;
    }
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  } catch (_) {
    return ThemeMode.system;
  }
}

Future<void> _saveThemeMode(ThemeMode mode) async {
  final value = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    _ => 'system',
  };
  try {
    await SimplePrefs.setString(_themeModeKey, value);
  } catch (_) {
    // ignore persistence errors
  }
}

class PortfolioBrainApp extends StatefulWidget {
  final ApiServerConfig initialConfig;
  final String? initialToken;
  final String? initialRefreshToken;
  final ThemeMode initialThemeMode;

  const PortfolioBrainApp({
    super.key,
    required this.initialConfig,
    required this.initialToken,
    required this.initialRefreshToken,
    required this.initialThemeMode,
  });

  @override
  State<PortfolioBrainApp> createState() => _PortfolioBrainAppState();
}

class _PortfolioBrainAppState extends State<PortfolioBrainApp> {
  int _index = 0;

  late ApiServerConfig _config;
  String? _token;
  ThemeMode _themeMode = ThemeMode.system;
  int _configVersion = 0;
  int _homeReloadVersion = 0;

  @override
  void initState() {
    super.initState();

    _config = widget.initialConfig;
    _token = widget.initialToken;
    _themeMode = widget.initialThemeMode;
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
      _configVersion++;
    });
  }

  Future<void> _setTokens(String? accessToken, String? refreshToken) async {
    ApiClient.setTokens(accessToken, refreshToken);
    if (accessToken == null || refreshToken == null) {
      await AuthStorage.clearTokens();
    } else {
      await AuthStorage.saveTokens(accessToken, refreshToken);
    }
    if (!mounted) return;
    setState(() {
      _token = accessToken;
      _index = 0;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await _saveThemeMode(mode);
    if (!mounted) return;
    setState(() {
      _themeMode = mode;
    });
  }

  void _refreshHome({bool ensureIndex = false}) {
    setState(() {
      _homeReloadVersion++;
      if (ensureIndex) {
        _index = 0;
      }
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

  List<Widget> _buildPages() {
    final version = _configVersion;
    return [
      KeyedSubtree(
        key: ValueKey('home_${version}_$_homeReloadVersion'),
        child: const HomePage(),
      ),
      KeyedSubtree(
        key: ValueKey('accounts_$version'),
        child: const AccountsPage(),
      ),
      KeyedSubtree(
        key: ValueKey('investments_$version'),
        child: const InvestmentsPage(),
      ),
      KeyedSubtree(
        key: ValueKey('cashflow_$version'),
        child: const CashflowPage(),
      ),
      KeyedSubtree(
        key: ValueKey('agent_chat_$version'),
        child: const AgentChatPage(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'AI资产管理',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 14),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 11),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontSize: 13),
          labelSmall: TextStyle(fontSize: 12),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 14),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 11),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontSize: 13),
          labelSmall: TextStyle(fontSize: 12),
        ),
      ),
      themeMode: _themeMode,

      home: _config.isConfigured
          ? (_token == null
              ? Builder(
                  builder: (context) {
                    return LoginPage(
                      onConfigRequested: () => _openServerConfig(context),
                      onLoggedIn: (accessToken, refreshToken) => _setTokens(accessToken, refreshToken),
                    );
                  },
                )
              : Builder(
                  builder: (context) {
                    return Scaffold(
                      appBar: AppBar(
                        title: const Text('AI资产管理'),
                        actions: [
                          PopupMenuButton<ThemeMode>(
                            tooltip: '主题模式',
                            initialValue: _themeMode,
                            onSelected: _setThemeMode,
                            icon: Icon(
                              switch (_themeMode) {
                                ThemeMode.light => Icons.light_mode_outlined,
                                ThemeMode.dark => Icons.dark_mode_outlined,
                                _ => Icons.brightness_auto_outlined,
                              },
                            ),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: ThemeMode.system,
                                child: ListTile(
                                  leading: Icon(Icons.brightness_auto_outlined),
                                  title: Text('跟随系统'),
                                ),
                              ),
                              PopupMenuItem(
                                value: ThemeMode.light,
                                child: ListTile(
                                  leading: Icon(Icons.light_mode_outlined),
                                  title: Text('浅色'),
                                ),
                              ),
                              PopupMenuItem(
                                value: ThemeMode.dark,
                                child: ListTile(
                                  leading: Icon(Icons.dark_mode_outlined),
                                  title: Text('深色'),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: '服务器配置',
                            onPressed: () => _openServerConfig(context),
                            icon: const Icon(Icons.settings_ethernet_rounded),
                          ),
                          IconButton(
                            tooltip: '退出登录',
                            onPressed: () => _setTokens(null, null),
                            icon: const Icon(Icons.logout),
                          ),
                        ],
                      ),

                      // 保持页面状态
                      body: IndexedStack(
                        index: _index,
                        children: _buildPages(),
                      ),

                      // Material 3 NavigationBar
                      bottomNavigationBar: NavigationBar(
                        selectedIndex: _index,

                        onDestinationSelected: (i) {
                          if (i == 0) {
                            _refreshHome(ensureIndex: true);
                            return;
                          }

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
                ))
          : ServerConfigPage(
              initialConfig: _config,
              onSaved: _applyConfig,
            ),
    );
  }
}
