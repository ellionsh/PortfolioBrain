import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../api/api_client.dart';
import '../utils/error_format.dart';

class AgentChatPage extends StatefulWidget {
  const AgentChatPage({super.key});

  @override
  State<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends State<AgentChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [];
  bool _loading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add(_Message(role: 'user', content: text));
      _loading = true;
      _controller.clear();
    });
    try {
      final resp = await ApiClient.chat(text);
      setState(() {
        _messages.add(_Message(role: 'assistant', content: resp));
      });
    } catch (e) {
      setState(() {
        _messages.add(
          _Message(role: 'assistant', content: '出错了：${formatApiError(e)}'),
        );
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('智能资产助手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final align = m.role == 'user' ? Alignment.centerRight : Alignment.centerLeft;
                final color = m.role == 'user' ? Colors.blue[100] : Colors.grey[200];
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: m.role == 'assistant'
                        ? MarkdownBody(data: m.content)
                        : Text(m.content),
                  ),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '问问：未来三个月会不会缺钱？',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String role;
  final String content;
  _Message({required this.role, required this.content});
}
