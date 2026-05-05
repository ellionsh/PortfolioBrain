// lib/pages/chat_page.dart
import 'package:flutter/material.dart';
import '../services/api.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  String reply = "";

  Future<void> ask() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;

    setState(() => reply = "思考中…");

    final data = await Api.postJson("/chat", {"query": q});
    setState(() => reply = data["response"]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "问 PortfolioBrain：例如：未来三个月我会缺钱吗",
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: ask, child: const Text("发送")),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(reply, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
