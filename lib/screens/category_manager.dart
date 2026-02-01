import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_category.dart';

class CategoryManager extends StatefulWidget {
  final String userId;

  const CategoryManager({Key? key, required this.userId}) : super(key: key);

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> expenseCategories = [];
  List<Map<String, dynamic>> incomeCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      // Fetch default expense categories (userId is null)
      final defaultExpenseResponse = await Supabase.instance.client
          .from('Category')
          .select()
          .eq('type', 'expense')
          .isFilter('userId', null)
          .order('categoryId');

      // Fetch user's custom expense categories
      final userExpenseResponse = await Supabase.instance.client
          .from('Category')
          .select()
          .eq('type', 'expense')
          .eq('userId', widget.userId)
          .order('categoryId');

      // Fetch default income categories (userId is null)
      final defaultIncomeResponse = await Supabase.instance.client
          .from('Category')
          .select()
          .eq('type', 'income')
          .isFilter('userId', null)
          .order('categoryId');

      // Fetch user's custom income categories
      final userIncomeResponse = await Supabase.instance.client
          .from('Category')
          .select()
          .eq('type', 'income')
          .eq('userId', widget.userId)
          .order('categoryId');

      setState(() {
        expenseCategories = <Map<String, dynamic>>[
          ...List<Map<String, dynamic>>.from(defaultExpenseResponse as List),
          ...List<Map<String, dynamic>>.from(userExpenseResponse as List),
        ];
        incomeCategories = <Map<String, dynamic>>[
          ...List<Map<String, dynamic>>.from(defaultIncomeResponse as List),
          ...List<Map<String, dynamic>>.from(userIncomeResponse as List),
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching categories: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading categories: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9E6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Category Manager',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF90EE90),
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'Expense'),
                Tab(text: 'Income'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF90EE90)),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Expense Tab
                      _buildCategoryGrid(expenseCategories),
                      // Income Tab
                      _buildCategoryGrid(incomeCategories),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFD700),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateCategory(userId: widget.userId),
            ),
          );
          // Refresh categories if a new one was created
          if (result == true) {
            await _fetchCategories();
          }
        },
        child: const Text(
          'Add\nCategory',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCategoryGrid(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No categories found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.90,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryItem(category);
      },
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    return GestureDetector(
      onTap: () {
        // TODO: Handle category tap - could open edit/delete options
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${category['name']} tapped')));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Icon Container
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFB0E0E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: category['icon'] != null && category['icon'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        category['icon'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.category,
                            color: Colors.grey[600],
                            size: 40,
                          );
                        },
                      ),
                    )
                  : Icon(Icons.category, color: Colors.grey[600], size: 40),
            ),
            const SizedBox(height: 8),
            // Category Name
            SizedBox(
              height: 40,
              width: 80,
              child: Text(
                category['name'] ?? 'Unknown',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
