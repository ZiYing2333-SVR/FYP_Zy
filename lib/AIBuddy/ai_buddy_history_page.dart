import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_buddy_detail_page.dart';

class AiBuddyHistoryPage extends StatefulWidget {
  final String userId;

  const AiBuddyHistoryPage({
    super.key,
    required this.userId,
  });

  @override
  State<AiBuddyHistoryPage> createState() => _AiBuddyHistoryPageState();
}

class _AiBuddyHistoryPageState extends State<AiBuddyHistoryPage> {
  final supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> groupedByDate = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await supabase
          .from('AIQuery')
          .select()
          .eq('userId', widget.userId)
          .order('createdAt', ascending: false);

      final Map<String, List<Map<String, dynamic>>> sessionMap = {};

      for (final item in data) {
        final sessionId = item['sessionId'] ?? item['queryId'];
        sessionMap.putIfAbsent(sessionId, () => []);
        sessionMap[sessionId]!.add(Map<String, dynamic>.from(item));
      }

      final Map<String, List<Map<String, dynamic>>> byDate = {};

      for (final entry in sessionMap.entries) {
        final sessionItems = entry.value;

        sessionItems.sort((a, b) {
          final aDate = a['createdAt'] != null
              ? DateTime.parse(a['createdAt'])
              : DateTime.now();
          final bDate = b['createdAt'] != null
              ? DateTime.parse(b['createdAt'])
              : DateTime.now();
          return aDate.compareTo(bDate);
        });

        final firstItem = sessionItems.first;
        final createdAt = firstItem['createdAt'] != null
            ? DateTime.parse(firstItem['createdAt']).toLocal()
            : DateTime.now();

        final dateKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

        final sessionData = {
          'sessionId': entry.key,
          'title': firstItem['queryText'] ?? 'Untitled Chat',
          'createdAt': firstItem['createdAt'],
        };

        byDate.putIfAbsent(dateKey, () => []);
        byDate[dateKey]!.add(sessionData);
      }

      setState(() {
        groupedByDate = byDate;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading AI history: $e');
      setState(() => isLoading = false);
    }
  }

  String _shortTitle(String text) {
    if (text.length <= 35) return text;
    return '${text.substring(0, 35)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Chat History',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedByDate.isEmpty
          ? const Center(
        child: Text(
          'No chat history yet',
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: groupedByDate.entries.map((entry) {
          final date = entry.key;
          final sessions = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...sessions.map((session) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    title: Text(
                      _shortTitle(session['title']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiBuddyHistoryDetailPage(
                            sessionId: session['sessionId'],
                            title: session['title'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ),
    );
  }
}