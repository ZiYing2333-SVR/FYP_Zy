import 'package:flutter/material.dart';
import 'package:fyp_zy/FinancialTip/tip_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TipListPage extends StatefulWidget {
  final String tipCategoryId;
  final String categoryTitle;
  final String? tipIconUrl;

  const TipListPage({
    super.key,
    required this.tipCategoryId,
    required this.categoryTitle,
    this.tipIconUrl,
  });

  @override
  State<TipListPage> createState() => _TipListPageState();
}

class _TipListPageState extends State<TipListPage> {
  List<dynamic> tips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTipsByCategory();
  }

  Future<void> _loadTipsByCategory() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('FinancialTip')
          .select('tipId, title')
          .eq('tipCategoryId', widget.tipCategoryId)
          .order('tipId');

      setState(() {
        tips = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading tips: $e');
      setState(() => isLoading = false);
    }
  }

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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🏷 CATEGORY HEADER (ICON + TITLE)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.tipIconUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.tipIconUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 36,
                        height: 36,
                      ),
                    ),
                  ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    widget.categoryTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 📋 TIP LIST
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : tips.isEmpty
                  ? const Center(child: Text('No tips found'))
                  : ListView.builder(
                itemCount: tips.length,
                itemBuilder: (context, index) {
                  final tip = tips[index];
                  return _buildTipItem(
                    title: tip['title'],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TipDetailPage(
                            tipId: tip['tipId'],
                          ),
                        ),
                      );
                    },

                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 SINGLE TIP CARD
  Widget _buildTipItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF555555), // dark grey

                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
