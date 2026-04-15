import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_budget_page_2.dart';

class CreateBudgetPage extends StatefulWidget {
  final String userId;

  const CreateBudgetPage({super.key, required this.userId});

  @override
  State<CreateBudgetPage> createState() => _CreateBudgetPageState();
}

class _CreateBudgetPageState extends State<CreateBudgetPage> {
  Future<void> _selectLedger() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SelectionPage(
          title: 'Select Ledger',
          tableName: 'Ledger',
          displayField: 'name',
          userId: widget.userId,
        ),
      ),
    );

    if (result != null) {
      // Navigate to page 2 with ledger selected
      final budgetCreated = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBudgetPage2(
            userId: widget.userId,
            ledgerId: result['id'],
            categoryId: null,
            accountId: null,
          ),
        ),
      );

      // If budget was created successfully, go back to budget page
      if (budgetCreated == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _selectCategory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SelectionPage(
          title: 'Select Category',
          tableName: 'Category',
          displayField: 'name',
          userId: widget.userId,
        ),
      ),
    );

    if (result != null) {
      // Navigate to page 2 with category selected
      final budgetCreated = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBudgetPage2(
            userId: widget.userId,
            ledgerId: null,
            categoryId: result['id'],
            accountId: null,
          ),
        ),
      );

      // If budget was created successfully, go back to budget page
      if (budgetCreated == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _selectAccount() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SelectionPage(
          title: 'Select Account',
          tableName: 'Account',
          displayField: 'accountName',
          userId: widget.userId,
        ),
      ),
    );

    if (result != null) {
      // Navigate to page 2 with account selected
      final budgetCreated = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBudgetPage2(
            userId: widget.userId,
            ledgerId: null,
            categoryId: null,
            accountId: result['id'],
          ),
        ),
      );

      // If budget was created successfully, go back to budget page
      if (budgetCreated == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9E6),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.black87, size: 28),
        ),
        title: const Text(
          'New Budget',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            _buildSelectionButton(title: 'Ledger', onTap: _selectLedger),
            const SizedBox(height: 16),
            _buildSelectionButton(title: 'Category', onTap: _selectCategory),
            const SizedBox(height: 16),
            _buildSelectionButton(title: 'Account', onTap: _selectAccount),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionPage extends StatefulWidget {
  final String title;
  final String tableName;
  final String displayField;
  final String userId;

  const _SelectionPage({
    required this.title,
    required this.tableName,
    required this.displayField,
    required this.userId,
  });

  @override
  State<_SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<_SelectionPage> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  Set<String> _itemsWithBudgets =
      {}; // Store IDs of items that already have budgets

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchExistingBudgets() async {
    try {
      final budgets = await Supabase.instance.client
          .from('Budget')
          .select()
          .eq('userId', widget.userId);

      final budgetIds = <String>{};
      for (final budget in budgets) {
        if (widget.tableName == 'Ledger' && budget['ledgerId'] != null) {
          budgetIds.add(budget['ledgerId']);
        } else if (widget.tableName == 'Account' &&
            budget['accountId'] != null) {
          budgetIds.add(budget['accountId']);
        } else if (widget.tableName == 'Category' &&
            budget['categoryId'] != null) {
          budgetIds.add(budget['categoryId']);
        }
      }
      setState(() {
        _itemsWithBudgets = budgetIds;
      });
    } catch (e) {
      print('Error fetching budgets: $e');
    }
  }

  Future<void> _fetchItems() async {
    try {
      setState(() => _isLoading = true);

      // Fetch existing budgets first
      await _fetchExistingBudgets();

      List<dynamic> response = [];

      if (widget.tableName == 'Account') {
        response = await Supabase.instance.client
            .from('Account')
            .select()
            .eq('userId', widget.userId);
        // Filter out Savings accounts (case insensitive)
        response = response.where((account) {
          final accountType = (account['accountType'] ?? '')
              .toString()
              .toUpperCase();
          return accountType != 'SAVINGS';
        }).toList();
      } else if (widget.tableName == 'Ledger') {
        response = await Supabase.instance.client
            .from('Ledger')
            .select()
            .eq('userId', widget.userId);
      } else if (widget.tableName == 'Category') {
        // Fetch both default categories (UID0000) and user-specific categories
        final defaultCategories = await Supabase.instance.client
            .from('Category')
            .select()
            .or('userId.eq.UID0000,userId.is.null');

        final userCategories = await Supabase.instance.client
            .from('Category')
            .select()
            .eq('userId', widget.userId);

        response = [...defaultCategories, ...userCategories];
        // Filter to only show Expense categories (case insensitive)
        response = response.where((category) {
          final type = (category['type'] ?? '').toString().toUpperCase();
          return type == 'EXPENSE';
        }).toList();
      }

      setState(() {
        _items = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching ${widget.tableName}: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading items: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getIdField() {
    switch (widget.tableName) {
      case 'Account':
        return 'accountId';
      case 'Ledger':
        return 'ledgerId';
      case 'Category':
        return 'categoryId';
      default:
        return 'id';
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.tableName.toLowerCase()} found',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final idField = _getIdField();
                final itemId = item[idField];
                final itemName = item[widget.displayField] ?? 'Unknown';
                final isDisabled = _itemsWithBudgets.contains(itemId);

                // Get icon based on table type
                String? iconPath;
                if (widget.tableName == 'Account') {
                  iconPath = item['iconImage'];
                } else if (widget.tableName == 'Category') {
                  iconPath = item['icon'];
                }

                return Column(
                  children: [
                    GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'id': itemId,
                                'name': itemName,
                              });
                            },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDisabled
                              ? Colors.grey.shade200
                              : Colors.green.shade200,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Icon display
                            if (iconPath != null && iconPath.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Image.network(
                                  iconPath,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.image_not_supported,
                                      size: 32,
                                      color: Colors.grey.shade400,
                                    );
                                  },
                                ),
                              ),
                            Expanded(
                              child: Text(
                                itemName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDisabled
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.check_circle,
                              color: isDisabled
                                  ? Colors.grey.shade400
                                  : Colors.green.shade600,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Show message for disabled ledgers
                    if (isDisabled && widget.tableName == 'Ledger')
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Already set budget',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
