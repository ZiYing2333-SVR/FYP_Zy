import 'package:flutter/material.dart';
import 'package:fyp_zy/FinancialTip/tip_list_page.dart';
import 'package:fyp_zy/FinancialTip/view_tips_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinancialTipLibraryPage extends StatefulWidget {
  final String userId;

  const FinancialTipLibraryPage({
    super.key,
    required this.userId,
  });

  @override
  State<FinancialTipLibraryPage> createState() =>
      _FinancialTipLibraryPageState();
}

class _FinancialTipLibraryPageState
    extends State<FinancialTipLibraryPage> {
  List<dynamic> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('TipCategory')
          .select('tipCategoryId, title, tipIcon')
          .order('tipCategoryId');

      setState(() {
        categories = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewTipsPage(userId: widget.userId),
              ),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🏷 Title UNDER AppBar
            const Text(
              'Finance Tips Library',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // 📂 Category list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _buildCategoryButton(
                    title: category['title'],
                    iconUrl: category['tipIcon'],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TipListPage(
                            tipCategoryId: category['tipCategoryId'],
                            categoryTitle: category['title'],
                            tipIconUrl:category['tipIcon'],
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

  Widget _buildCategoryButton({
    required String title,
    required String iconUrl,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  iconUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.image_not_supported,
                      size: 32,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
