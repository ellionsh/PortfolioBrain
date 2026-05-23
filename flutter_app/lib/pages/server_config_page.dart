import 'package:flutter/material.dart';

import '../api/api_server_config.dart';
import '../theme/app_text_styles.dart';

class ServerConfigPage extends StatefulWidget {
  final ApiServerConfig initialConfig;
  final ValueChanged<ApiServerConfig> onSaved;
  final bool canCancel;

  const ServerConfigPage({
    super.key,
    required this.initialConfig,
    required this.onSaved,
    this.canCancel = false,
  });

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late String _scheme;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.initialConfig.host);
    _portController =
        TextEditingController(text: widget.initialConfig.port.toString());
    _scheme = widget.initialConfig.scheme;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写有效的服务器地址和端口')),
      );
      return;
    }

    setState(() => _saving = true);
    final config = await ApiServerConfig.save(
      host: host,
      port: port,
      scheme: _scheme,
    );
    if (!mounted) return;
    widget.onSaved(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.canCancel
          ? AppBar(
              title: const Text('服务器配置'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '连接服务器',
                    style: AppTextStyles.pageTitle,
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'http', label: Text('HTTP')),
                      ButtonSegment(value: 'https', label: Text('HTTPS')),
                    ],
                    selected: {_scheme},
                    onSelectionChanged: (value) {
                      setState(() => _scheme = value.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: '例如 192.168.71.31',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      hintText: '例如 5000',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('保存并进入'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
