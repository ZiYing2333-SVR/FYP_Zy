import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'ai_buddy_history_page.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.isUser,
  });
}

class AiBuddyPage extends StatefulWidget {
  final String userId;

  const AiBuddyPage({
    super.key,
    required this.userId,
  });

  @override
  State<AiBuddyPage> createState() => _AiBuddyPageState();
}

class _AiBuddyPageState extends State<AiBuddyPage> {
  final ScrollController _scrollController = ScrollController();
  final supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  String? _sessionId;

  bool isLoading = false;
  final List<ChatMessage> _messages = [];

  /// Gemini API Key
  final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? "No Key";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiBuddyHistoryPage(userId: widget.userId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          /// Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/ai.png', width: 40),
              const SizedBox(width: 8),
              const Text(
                'AI Buddy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// Chat Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildChatArea(),
            ),
          ),

          ///  Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  // ===============================
  // CHAT AREA
  // ===============================
  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 180,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Text(
            "What's on your mind today?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index){
        final message = _messages[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Align(
            alignment: message.isUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: _chatBubble(
              text: message.text,
              isUser: message.isUser,
            ),
          ),
        );
      },
    );
  }

  // ===============================
  // CHAT BUBBLE
  // ===============================
  Widget _chatBubble({
    required String text,
    required bool isUser,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUser
            ? const Color(0xFFA7E399)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: isUser ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  // ===============================
  // INPUT BAR
  // ===============================
  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 15,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ask here...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(
                  Icons.send,
                  color: Color(0xFFA7E399),
                ),
                onPressed: isLoading ? null : _askGemini,
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ===============================
  // GEMINI API CALL (LOGIC UNCHANGED)
  // ===============================
  Future<void> _askGemini() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    _controller.clear();

    setState(() {
      isLoading = true;
      _messages.add(ChatMessage(text: question, isUser: true));
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$geminiApiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                  "You are a friendly financial assistant. Reply in plain text only. Keep answers short, clear, and practical by default, around 2 to 6 sentences. Only give a longer explanation if the user explicitly asks for more details, examples, step-by-step guidance, or a deeper explanation. Do not use markdown, asterisks, bold formatting, or bullet symbols.\n\nUser question:\n$question"
                }
              ]
            }
          ]
        }),
      );

      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        throw Exception(data['error']['message']);
      }

      final reply = data['candidates'][0]['content']['parts'][0]['text']
          .replaceAll('**', '')
          .replaceAll('* ', '• ');

      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
      _scrollToBottom();

      final queryId = await _generateQueryId();
      await supabase.from('AIQuery').insert({
        'queryId': queryId,
        'sessionId': _sessionId,
        'userId': widget.userId,
        'queryText': question,
        'aiResponse': reply,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: '❌ Gemini error:\n$e',
            isUser: false,
          ),
        );
        _scrollToBottom();
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  // ===============================
  // AI001 AUTO INCREMENT
  // ===============================
  Future<String> _generateQueryId() async {
    final res = await supabase
        .from('AIQuery')
        .select('queryId')
        .order('queryId', ascending: false)
        .limit(1);

    if (res.isEmpty) return 'AI001';

    final last = res.first['queryId'];
    final num = int.parse(last.substring(2)) + 1;
    return 'AI${num.toString().padLeft(3, '0')}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _createSessionId();
  }

  void _createSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _sessionId = 'S$now';
  }

}
