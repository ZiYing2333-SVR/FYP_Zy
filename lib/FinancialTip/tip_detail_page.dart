import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TipDetailPage extends StatefulWidget {
  final String tipId;

  const TipDetailPage({
    super.key,
    required this.tipId,
  });

  @override
  State<TipDetailPage> createState() => _TipDetailPageState();
}

class _TipDetailPageState extends State<TipDetailPage> {
  Map<String, dynamic>? tip;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTipDetail();
  }

  Future<void> _loadTipDetail() async {
    try {
      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('FinancialTip')
          .select('''
            tipId,
            title,
            subTitle,
            content,
            tipCategory:tipCategoryId (
              title,
              tipIcon
            )
          ''')
          .eq('tipId', widget.tipId)
          .single();

      setState(() {
        tip = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading tip detail: $e');
      setState(() => isLoading = false);
    }
  }

  /// 🖼 Get category icon URL (already PUBLIC URL)
  String? get iconUrl => tip?['tipCategory']?['tipIcon'];

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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : tip == null
          ? const Center(child: Text('Tip not found'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼 Icon + Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (iconUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      iconUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image, size: 48),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip!['tipCategory']?['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),


            // Content
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🏷 Title
              Text(
                tip!['title'],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // 📌 Subtitle with icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 30,
                    color: Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tip!['subTitle'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 📖 Content (JUSTIFIED)
              Text(
                tip!['content'],
                textAlign: TextAlign.justify, // ✅ justify text
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.6,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        ],
        ),
      ),
    );
  }
}
