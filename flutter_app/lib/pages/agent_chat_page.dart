import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../api/api_client.dart';
import '../utils/error_format.dart';

class AgentChatPage extends StatefulWidget {
  const AgentChatPage({super.key});

  @override
  State<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends State<AgentChatPage> {
  static const String _historyKey = 'agent_chat_history';
  static const String _historyInitKey = 'agent_chat_history_initialized';
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_Message> _messages = [];
  bool _loading = false;
  bool _isAtBottom = true;
  bool _showNewMessage = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels <= 48;
    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        if (_isAtBottom) {
          _showNewMessage = false;
          _unreadCount = 0;
        }
      });
    }
  }

  void _scrollToBottom({bool force = false, bool newAssistantMessage = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!force && !_isAtBottom) {
        if (newAssistantMessage) {
          setState(() {
            _showNewMessage = true;
            _unreadCount += 1;
          });
        } else if (!_showNewMessage) {
          setState(() {
            _showNewMessage = true;
          });
        }
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add(_Message(role: 'user', content: text));
      _loading = true;
      _controller.clear();
    });
    _saveHistory();
    _scrollToBottom(force: true);
    try {
      final resp = await ApiClient.chat(text);
      setState(() {
        _messages.add(_Message(role: 'assistant', content: resp));
      });
      _saveHistory();
      _scrollToBottom(newAssistantMessage: true);
    } catch (e) {
      setState(() {
        _messages.add(
          _Message(role: 'assistant', content: '出错了：${formatApiError(e)}'),
        );
      });
      _saveHistory();
      _scrollToBottom(newAssistantMessage: true);
    } finally {
      setState(() {
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final initialized = prefs.getBool(_historyInitKey) ?? false;
    if (!initialized) {
      await prefs.remove(_historyKey);
      await prefs.setBool(_historyInitKey, true);
      return;
    }
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final loaded = decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => _Message.fromJson(m))
          .toList();
      if (loaded.isEmpty) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
      });
      _scrollToBottom(force: true);
    } catch (_) {
      return;
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _messages.map((m) => m.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(data));
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() {
      _messages.clear();
      _showNewMessage = false;
      _unreadCount = 0;
    });
    _scrollToBottom(force: true);
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有对话记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '智能资产助手',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: '清空历史',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _confirmClearHistory,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: _messages.length + (_loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_loading && i == _messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('正在思考...'),
                            ],
                          ),
                        ),
                      );
                    }
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
                if (_showNewMessage)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: () => _scrollToBottom(force: true),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              '有新消息',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          if (_unreadCount > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[600],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                constraints: const BoxConstraints(minWidth: 18),
                                child: Text(
                                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory _Message.fromJson(Map<String, dynamic> json) {
    return _Message(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
    );
  }
}
