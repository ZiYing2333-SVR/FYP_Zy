import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AiBuddyPage extends StatefulWidget {
  const AiBuddyPage({super.key});

  @override
  State<AiBuddyPage> createState() => _AiBuddyPageState();
}

class _AiBuddyPageState extends State<AiBuddyPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();

  bool isLoading = false;
  String? aiReply;
  String _lastQuestionText = '';

  /// Gemini API Key
  static const String geminiApiKey =
      'AIzaSyCeRfAHd65Ranoopkf1Xhf9qAPXZXPWhMo';

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
    if (aiReply == null) {
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
                offset: const Offset(0, 6), // downwards
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

    return SingleChildScrollView(
      child: Column(
        children: [
          /// User bubble
          Align(
            alignment: Alignment.centerRight,
            child: _chatBubble(
              text: _lastQuestionText,
              isUser: true,
            ),
          ),

          const SizedBox(height: 12),

          /// AI bubble
          Align(
            alignment: Alignment.centerLeft,
            child: _chatBubble(
              text: aiReply!,
              isUser: false,
            ),
          ),
        ],
      ),
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

    _lastQuestionText = question;

    setState(() {
      isLoading = true;
      aiReply = null;
    });

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
                  "You are a friendly financial assistant. Give simple, helpful advice.\n\nUser question:\n$question"
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

      final reply =
      data['candidates'][0]['content']['parts'][0]['text'];

      setState(() => aiReply = reply);

      final queryId = await _generateQueryId();
      await supabase.from('AIQuery').insert({
        'queryId': queryId,
        'queryText': question,
        'aiResponse': reply,
      });

      _controller.clear();
    } catch (e) {
      setState(() => aiReply = '❌ Gemini error:\n$e');
    }

    setState(() => isLoading = false);
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
}
