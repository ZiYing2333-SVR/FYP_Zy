import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiBuddyHistoryDetailPage extends StatefulWidget {
  final String sessionId;
  final String title;

  const AiBuddyHistoryDetailPage({
    super.key,
    required this.sessionId,
    required this.title,
  });

  @override
  State<AiBuddyHistoryDetailPage> createState() =>
      _AiBuddyHistoryDetailPageState();
}

class _AiBuddyHistoryDetailPageState extends State<AiBuddyHistoryDetailPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> chats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionChats();
  }

  Future<void> _loadSessionChats() async {
    try {
      final data = await supabase
          .from('AIQuery')
          .select()
          .eq('sessionId', widget.sessionId)
          .order('createdAt', ascending: true);

      setState(() {
        chats = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading session chats: $e');
      setState(() => isLoading = false);
    }
  }

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
            : Colors.white.withValues(alpha: 0.9),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final item = chats[index];

          return Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _chatBubble(
                  text: item['queryText'] ?? '',
                  isUser: true,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _chatBubble(
                  text: item['aiResponse'] ?? '',
                  isUser: false,
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}