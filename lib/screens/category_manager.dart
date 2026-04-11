import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_category.dart';
import 'edit_category.dart';

class CategoryManager extends StatefulWidget {
  final String userId;

  const CategoryManager({Key? key, required this.userId}) : super(key: key);

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> defaultExpenseCategories = [];
  List<Map<String, dynamic>> userExpenseCategories = [];
  List<Map<String, dynamic>> defaultIncomeCategories = [];
  List<Map<String, dynamic>> userIncomeCategories = [];
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
        defaultExpenseCategories = List<Map<String, dynamic>>.from(
          defaultExpenseResponse as List,
        );
        userExpenseCategories = List<Map<String, dynamic>>.from(
          userExpenseResponse as List,
        );
        defaultIncomeCategories = List<Map<String, dynamic>>.from(
          defaultIncomeResponse as List,
        );
        userIncomeCategories = List<Map<String, dynamic>>.from(
          userIncomeResponse as List,
        );
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
          // Tab Bar with pill-style indicator
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 400 ? 12 : 24,
              vertical: MediaQuery.of(context).size.width < 400 ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: const Color(0xFFA7E399),
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
                      _buildCategorySection(
                        defaultExpenseCategories,
                        userExpenseCategories,
                      ),
                      // Income Tab
                      _buildCategorySection(
                        defaultIncomeCategories,
                        userIncomeCategories,
                      ),
                    ],
                  ),
          ),
          // Add Category Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateCategory(userId: widget.userId),
                    ),
                  );
                  // Refresh categories if a new one was created
                  if (result == true) {
                    await _fetchCategories();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA7E399),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Add Category'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    List<Map<String, dynamic>> defaultCategories,
    List<Map<String, dynamic>> userCategories,
  ) {
    if (defaultCategories.isEmpty && userCategories.isEmpty) {
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Default Categories Section
          if (defaultCategories.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Default Categories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            _buildCategoryGrid(defaultCategories),
          ],
          // User Categories Section
          if (userCategories.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'My Categories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            _buildCategoryGrid(userCategories),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<Map<String, dynamic>> categories) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 400 ? 2 : 3;
    final crossAxisSpacing = screenWidth < 400 ? 12.0 : 16.0;
    final mainAxisSpacing = screenWidth < 400 ? 16.0 : 24.0;
    final childAspectRatio = screenWidth < 400 ? 0.85 : 0.90;
    final padding = screenWidth < 400 ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding / 2),
      child: GridView.builder(
        padding: EdgeInsets.all(padding / 2),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryItem(category);
        },
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 400 ? 55.0 : 70.0;
    final textWidth = screenWidth < 400 ? 65.0 : 80.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditCategory(
              categoryId: category['categoryId'],
              category: category,
              userId: widget.userId,
            ),
          ),
        ).then((refreshNeeded) {
          // If the edit was successful, refresh categories
          if (refreshNeeded == true) {
            _fetchCategories();
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Icon Container
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
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
                            size: iconSize * 0.5,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.category,
                      color: Colors.grey[600],
                      size: iconSize * 0.5,
                    ),
            ),
            const SizedBox(height: 8),
            // Category Name
            SizedBox(
              height: 40,
              width: textWidth,
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
