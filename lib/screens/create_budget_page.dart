import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateBudgetPage extends StatefulWidget {
  final String userId;

  const CreateBudgetPage({super.key, required this.userId});

  @override
  State<CreateBudgetPage> createState() => _CreateBudgetPageState();
}

class _CreateBudgetPageState extends State<CreateBudgetPage> {
  String? _selectedLedgerId;
  String? _selectedCategoryId;
  String? _selectedAccountId;

  String? _selectedLedgerName;
  String? _selectedCategoryName;
  String? _selectedAccountName;

  Future<void> _selectLedger() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SelectionPage(
          title: 'Select Ledger',
          tableName: 'Ledger',
          displayField: 'ledgerName',
          userId: widget.userId,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLedgerId = result['id'];
        _selectedLedgerName = result['name'];
      });
    }
  }

  Future<void> _selectCategory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SelectionPage(
          title: 'Select Category',
          tableName: 'Category',
          displayField: 'categoryName',
          userId: widget.userId,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCategoryId = result['id'];
        _selectedCategoryName = result['name'];
      });
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
      setState(() {
        _selectedAccountId = result['id'];
        _selectedAccountName = result['name'];
      });
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                // Validate selections
                if (_selectedLedgerId == null ||
                    _selectedCategoryId == null ||
                    _selectedAccountId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please select Ledger, Category, and Account',
                      ),
                    ),
                  );
                  return;
                }

                // Navigate to next step or create budget
                Navigator.pop(context, {
                  'ledgerId': _selectedLedgerId,
                  'categoryId': _selectedCategoryId,
                  'accountId': _selectedAccountId,
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.green, size: 24),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            _buildSelectionButton(
              title: 'Ledger',
              selected: _selectedLedgerName,
              onTap: _selectLedger,
            ),
            const SizedBox(height: 16),
            _buildSelectionButton(
              title: 'Category',
              selected: _selectedCategoryName,
              onTap: _selectCategory,
            ),
            const SizedBox(height: 16),
            _buildSelectionButton(
              title: 'Account',
              selected: _selectedAccountName,
              onTap: _selectAccount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionButton({
    required String title,
    required String? selected,
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
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      selected,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
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

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      setState(() => _isLoading = true);

      List<dynamic> response = [];

      if (widget.tableName == 'Account') {
        response = await Supabase.instance.client
            .from('Account')
            .select()
            .eq('userId', widget.userId);
      } else if (widget.tableName == 'Ledger') {
        response = await Supabase.instance.client
            .from('Ledger')
            .select()
            .eq('userId', widget.userId);
      } else if (widget.tableName == 'Category') {
        response = await Supabase.instance.client
            .from('Category')
            .select()
            .eq('userId', widget.userId);
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

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context, {'id': itemId, 'name': itemName});
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                        Expanded(
                          child: Text(
                            itemName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
