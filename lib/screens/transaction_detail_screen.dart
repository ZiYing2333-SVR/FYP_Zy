import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Challenge/challenge_tracking_service.dart';
import 'refund_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final String? userId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.userId,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  Map<String, dynamic>? _transaction;
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Edit controllers
  late TextEditingController _noteController;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _fetchTransactionDetails();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactionDetails() async {
    try {
      final supabase = Supabase.instance.client;

      print('Fetching transaction with ID: ${widget.transactionId}');

      final response = await supabase
          .from('Transaction')
          .select(
            '*, Category(name, icon, type), Subcategory(name), Account(accountName, iconImage)',
          )
          .eq('transactionId', widget.transactionId)
          .single();

      print('Transaction fetched successfully: $response');

      setState(() {
        _transaction = response;
        _noteController.text = response['note'] ?? '';
        _selectedAccountId = response['accountId'];
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching transaction details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('Account')
          .select('accountId, accountName, iconImage')
          .order('accountName');

      setState(() {
        _accounts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching accounts: $e');
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'No date';
    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _updateTransaction() async {
    if (_transaction == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('Transaction')
          .update({
            'note': _noteController.text,
            'accountId': _selectedAccountId,
          })
          .eq('transactionId', widget.transactionId);

      /// ✅ Recalculate preset challenge progress
      if (widget.userId != null) {
        await ChallengeTrackingService().updateUserChallenges(widget.userId!);
      }

      setState(() {
        _transaction!['note'] = _noteController.text;
        _transaction!['accountId'] = _selectedAccountId;
        _isEditing = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating transaction: $e');
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating transaction: $e')),
        );
      }
    }
  }

  Future<void> _deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: const Text(
          'Delete Transaction',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF39C12),
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this transaction? The amount will be returned to the account.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFF39C12)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && _transaction != null) {
      try {
        final supabase = Supabase.instance.client;

        // 1. Get current account balance
        final accountResponse = await supabase
            .from('Account')
            .select('balance')
            .eq('accountId', _transaction!['accountId'])
            .single();

        final currentBalance =
            double.tryParse(accountResponse['balance'].toString()) ?? 0;
        final amount = double.tryParse(_transaction!['amount'].toString()) ?? 0;
        final type = _transaction!['type']?.toString().toLowerCase();

        // 2. Calculate new balance (return amount to account)
        double newBalance;
        if (type == 'income') {
          // If it was income, subtract it (return it)
          newBalance = currentBalance - amount;
        } else {
          // If it was expense, add it back (return it)
          newBalance = currentBalance + amount;
        }

        // 3. Update account balance
        await supabase
            .from('Account')
            .update({'balance': newBalance})
            .eq('accountId', _transaction!['accountId']);

        // 4. Delete transaction
        await supabase
            .from('Transaction')
            .delete()
            .eq('transactionId', widget.transactionId);

        /// ✅ Recalculate preset challenge progress
        if (widget.userId != null) {
          await ChallengeTrackingService().updateUserChallenges(widget.userId!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted successfully')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        print('Error deleting transaction: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting transaction: $e')),
          );
        }
      }
    }
  }

  void _navigateToRefund() {
    if (_transaction == null || widget.userId == null) return;

    final amount = double.tryParse(_transaction!['amount'].toString()) ?? 0;
    final accountName = _transaction!['Account']?['accountName'] ?? 'Account';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RefundScreen(
          transactionId: widget.transactionId,
          amount: amount,
          accountId: _transaction!['accountId'],
          accountName: accountName,
          userId: widget.userId!,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh transaction details and close
        Navigator.pop(context, true);
      }
    });
  }

  void _selectAccount() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: const Color(0xFFFEFFD3),
        child: ListView.builder(
          itemCount: _accounts.length,
          itemBuilder: (context, index) {
            final account = _accounts[index];
            return ListTile(
              leading:
                  account['iconImage'] != null &&
                      (account['iconImage'] as String).isNotEmpty
                  ? Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Image.network(
                        account['iconImage'],
                        fit: BoxFit.cover,
                      ),
                    )
                  : null,
              title: Text(account['accountName']),
              trailing: _selectedAccountId == account['accountId']
                  ? const Icon(Icons.check, color: Color(0xFF52C77A))
                  : null,
              onTap: () {
                setState(() {
                  _selectedAccountId = account['accountId'];
                });
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  bool _isRefunded() => _transaction?['refund'] == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.black),
        ),
        title: const Text(
          'Transaction',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isRefunded() && !_isEditing)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isEditing = true;
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Icon(Icons.edit, color: Colors.black),
              ),
            ),
          if (_isEditing)
            GestureDetector(
              onTap: _updateTransaction,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, color: Color(0xFF52C77A)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
          ? const Center(child: Text('Transaction not found'))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Amount Display
                    Text(
                      'RM ${double.tryParse(_transaction!['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color:
                            _transaction!['type']?.toString().toLowerCase() ==
                                'income'
                            ? const Color(0xFF52C77A)
                            : const Color(0xFFE74C3C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Refund Badge
                    if (_isRefunded())
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5B4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'REFUNDED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE74C3C),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Transaction Details
                    _buildDetailField(
                      'Type',
                      (_transaction!['type']?.toString().toUpperCase() ??
                          'EXPENSE'),
                      isEditable: false,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailField(
                      'Category',
                      (_transaction!['Category']?['name'] ?? 'N/A'),
                      isEditable: false,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailField(
                      'Subcategory',
                      (_transaction!['Subcategory']?['name'] ?? 'N/A'),
                      isEditable: false,
                    ),
                    const SizedBox(height: 12),
                    _isEditing
                        ? GestureDetector(
                            onTap: _selectAccount,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA7E399),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Account',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _accounts.firstWhere(
                                                (a) =>
                                                    a['accountId'] ==
                                                    _selectedAccountId,
                                                orElse: () => {
                                                  'accountName':
                                                      'Select Account',
                                                },
                                              )['accountName'] ??
                                              'Select Account',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildDetailField(
                            'Account',
                            (_transaction!['Account']?['accountName'] ?? 'N/A'),
                            isEditable: false,
                          ),
                    const SizedBox(height: 12),
                    _buildDetailField(
                      'Ledger',
                      (_transaction!['ledgerId'] ?? 'N/A'),
                      isEditable: false,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailField(
                      'Time',
                      _formatDateTime(_transaction!['date']),
                      isEditable: false,
                    ),
                    if (_isRefunded())
                      Column(
                        children: [
                          const SizedBox(height: 12),
                          _buildDetailField(
                            'Refund Date',
                            _formatDateTime(_transaction!['date']),
                            isEditable: false,
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    _isEditing
                        ? _buildNoteField()
                        : _buildDetailField(
                            'Note',
                            (_transaction!['note'] ?? 'No notes'),
                            isEditable: false,
                          ),
                    const SizedBox(height: 32),
                    // Action Buttons
                    if (!_isRefunded())
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Refund Button
                          GestureDetector(
                            onTap: _navigateToRefund,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF52C77A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.undo,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Refund',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48),
                          // Delete Button
                          GestureDetector(
                            onTap: _deleteTransaction,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE74C3C),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetailField(
    String label,
    String value, {
    bool isEditable = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFA7E399),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFA7E399),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Note',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter note...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              contentPadding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }
}
