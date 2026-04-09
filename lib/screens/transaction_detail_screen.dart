import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Challenge/challenge_tracking_service.dart';
import 'refund_screen.dart';
import 'home_screen.dart';

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
  late TextEditingController _amountController;
  String? _selectedAccountId;

  // Original values for comparison during edit
  String? _originalAccountId;
  double? _originalAmount;
  String? _originalNote;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _amountController = TextEditingController();
    _fetchTransactionDetails();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
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
        _amountController.text =
            (double.tryParse(response['amount']?.toString() ?? '0') ?? 0)
                .toStringAsFixed(2);
        _selectedAccountId = response['accountId'];
        _originalAccountId = response['accountId'];
        _originalAmount =
            double.tryParse(response['amount']?.toString() ?? '0') ?? 0;
        _originalNote = response['note'] ?? '';
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
      final newAmount =
          double.tryParse(_amountController.text) ?? _originalAmount ?? 0;
      final transactionType =
          _transaction!['type']?.toString().toLowerCase() ?? 'expense';

      // Check what changed
      final accountChanged = _selectedAccountId != _originalAccountId;
      final amountChanged = newAmount != _originalAmount;

      // Handle account and amount adjustments
      if (accountChanged || amountChanged) {
        // Get current balances for affected accounts
        final accountIds = <String>{};
        if (_originalAccountId != null) accountIds.add(_originalAccountId!);
        if (_selectedAccountId != null) accountIds.add(_selectedAccountId!);

        for (final accountId in accountIds) {
          final accountResponse = await supabase
              .from('Account')
              .select('balance')
              .eq('accountId', accountId)
              .single();

          final currentBalance =
              double.tryParse(accountResponse['balance'].toString()) ?? 0;
          double newBalance = currentBalance;

          if (accountChanged && !amountChanged) {
            // Account changed, amount stays same
            if (accountId == _originalAccountId) {
              // Add back amount to original account
              if (transactionType == 'income') {
                newBalance = currentBalance - _originalAmount!;
              } else {
                newBalance = currentBalance + _originalAmount!;
              }
            } else if (accountId == _selectedAccountId) {
              // Deduct amount from new account
              if (transactionType == 'income') {
                newBalance = currentBalance + _originalAmount!;
              } else {
                newBalance = currentBalance - _originalAmount!;
              }
            }
          } else if (!accountChanged && amountChanged) {
            // Account stayed same, amount changed
            if (accountId == _originalAccountId) {
              // Add back original amount and deduct new amount
              if (transactionType == 'income') {
                newBalance = currentBalance - _originalAmount! + newAmount;
              } else {
                newBalance = currentBalance + _originalAmount! - newAmount;
              }
            }
          } else if (accountChanged && amountChanged) {
            // Both changed
            if (accountId == _originalAccountId) {
              // Add back original amount to original account
              if (transactionType == 'income') {
                newBalance = currentBalance - _originalAmount!;
              } else {
                newBalance = currentBalance + _originalAmount!;
              }
            } else if (accountId == _selectedAccountId) {
              // Deduct new amount from new account
              if (transactionType == 'income') {
                newBalance = currentBalance + newAmount;
              } else {
                newBalance = currentBalance - newAmount;
              }
            }
          }

          // Only update if balance changed
          if (!accountChanged && amountChanged) {
            // Amount only changed
            await supabase
                .from('Account')
                .update({'balance': newBalance})
                .eq('accountId', accountId);
          } else if (accountChanged) {
            // Account changed (with or without amount change)
            await supabase
                .from('Account')
                .update({'balance': newBalance})
                .eq('accountId', accountId);
          }
        }
      }

      // Update transaction in database
      await supabase
          .from('Transaction')
          .update({
            'note': _noteController.text,
            'accountId': _selectedAccountId,
            'amount': newAmount,
          })
          .eq('transactionId', widget.transactionId);

      /// ✅ Recalculate preset challenge progress
      if (widget.userId != null) {
        await ChallengeTrackingService().updateUserChallenges(widget.userId!);
      }

      setState(() {
        _transaction!['note'] = _noteController.text;
        _transaction!['accountId'] = _selectedAccountId;
        _transaction!['amount'] = newAmount;
        _originalNote = _noteController.text;
        _originalAccountId = _selectedAccountId;
        _originalAmount = newAmount;
        _isEditing = false;
        _isSaving = false;
      });

      if (mounted) {
        // Show success dialog with same theme as edit_category
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: const Color(0xFFFFF9E6),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFA7E399),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Success title
                    const Text(
                      'Transaction Updated Successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF39C12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Success message
                    const Text(
                      'Your transaction has been updated successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Done button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(
                            context,
                            true,
                          ); // Return to previous page
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
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
    final isRefunded = _isRefunded();
    final type = _transaction!['type']?.toString().toLowerCase();
    final isIncome = type == 'income';

    final deleteMessage = isRefunded
        ? 'Are you sure you want to delete this transaction record? This will permanently delete the record. This action cannot be undone.'
        : (isIncome
              ? 'Are you sure you want to delete this transaction? The amount will be deducted from the account. This will permanently delete the record. This action cannot be undone.'
              : 'Are you sure you want to delete this transaction? The amount will be returned to the account. This will permanently delete the record. This action cannot be undone.');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF9E6),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red[100],
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[700],
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Delete Transaction?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                deleteMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons Row
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBCBCBC),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delete Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE74C3C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && _transaction != null) {
      try {
        final supabase = Supabase.instance.client;

        if (!isRefunded) {
          // For non-refunded transactions, reverse the account balance
          // 1. Get current account balance
          final accountResponse = await supabase
              .from('Account')
              .select('balance')
              .eq('accountId', _transaction!['accountId'])
              .single();

          final currentBalance =
              double.tryParse(accountResponse['balance'].toString()) ?? 0;
          final amount =
              double.tryParse(_transaction!['amount'].toString()) ?? 0;
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
        }

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
          // Show success dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: const Color(0xFFFFF9E6),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Success icon
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFA7E399),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Success title
                      const Text(
                        'Transaction Deleted!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF39C12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Success message
                      Text(
                        isRefunded
                            ? 'Transaction record has been permanently deleted.'
                            : 'Transaction of RM${(double.tryParse(_transaction!['amount'].toString()) ?? 0).toStringAsFixed(2)} has been permanently deleted.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Done button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    HomeScreen(userId: widget.userId ?? ''),
                              ),
                            );
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
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
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

  void _refundTransaction() {
    if (_transaction == null) return;
  void _navigateToRefund() {
    if (_transaction == null || widget.userId == null) return;

    final amount = double.tryParse(_transaction!['amount'].toString()) ?? 0;

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF9E6),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue[100],
                ),
                child: Icon(
                  Icons.info_rounded,
                  color: Colors.blue[700],
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Refund Transaction?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                'Are you sure you want to refund RM${amount.toStringAsFixed(2)} from this transaction?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons Row
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBCBCBC),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Refund Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF52C77A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Refund',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((confirmed) async {
      if (confirmed == true && _transaction != null) {
        try {
          final supabase = Supabase.instance.client;
          final amount =
              double.tryParse(_transaction!['amount'].toString()) ?? 0;
          final type = _transaction!['type']?.toString().toLowerCase();

          // 1. Get current account balance
          final accountResponse = await supabase
              .from('Account')
              .select('balance')
              .eq('accountId', _transaction!['accountId'])
              .single();

          final currentBalance =
              double.tryParse(accountResponse['balance'].toString()) ?? 0;

          // 2. Calculate new balance (return amount to account)
          double newBalance;
          if (type == 'income') {
            // If it was income, subtract it (return it)
            newBalance = currentBalance - amount;
          } else {
            // If it was expense, add it back (return it)
            newBalance = currentBalance + amount;
          }

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
          // 3. Update account balance
          await supabase
              .from('Account')
              .update({'balance': newBalance})
              .eq('accountId', _transaction!['accountId']);

          // 4. Mark transaction as refunded
          await supabase
              .from('Transaction')
              .update({'refund': true})
              .eq('transactionId', widget.transactionId);

          if (mounted) {
            // Show success dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: const Color(0xFFFFF9E6),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFE5B4),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Success icon
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFA7E399),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Success title
                        const Text(
                          'Transaction Refunded!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF39C12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Success message
                        Text(
                          'RM${amount.toStringAsFixed(2)} has been refunded to the account.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Done button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                              Navigator.pop(
                                context,
                                true,
                              ); // Return to previous page
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
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        } catch (e) {
          print('Error refunding transaction: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error refunding transaction: $e')),
            );
          }
        }
      }
    });
  }

  void _selectAccount() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: const Color(0xFFFFF9E6),
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
                        fit: BoxFit.contain,
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

  void _showCancelConfirmation() {
    if (!_hasChanges()) {
      setState(() {
        _isEditing = false;
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF9E6),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Discard Changes?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF39C12),
                ),
              ),
              const SizedBox(height: 12),
              // Description
              const Text(
                'You have unsaved changes. Are you sure you want to discard them?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Keep Editing Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA7E399),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Keep Editing',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Discard Changes Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _isEditing = false;
                      _noteController.text = _originalNote ?? '';
                      _amountController.text = (_originalAmount ?? 0)
                          .toStringAsFixed(2);
                      _selectedAccountId = _originalAccountId;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Discard Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasChanges() {
    final newAmount =
        double.tryParse(_amountController.text) ?? _originalAmount ?? 0;
    return _noteController.text != (_originalNote ?? '') ||
        _selectedAccountId != _originalAccountId ||
        newAmount != _originalAmount;
  }

  bool _isRefunded() => _transaction?['refund'] == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9E6),
        elevation: 0.5,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close_rounded, color: Colors.black, size: 26),
        ),
        title: const Text(
          'Transaction Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0.3,
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
            Row(
              children: [
                // Cancel Button
                GestureDetector(
                  onTap: _showCancelConfirmation,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Icon(Icons.close, color: Colors.black),
                  ),
                ),
                // Save Button
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
          ? Center(
              child: Text(
                'Transaction not found',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Refund Badge
                  if (_isRefunded())
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5B4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE74C3C),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE74C3C).withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: const Color(0xFFE74C3C),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'REFUNDED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE74C3C),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isRefunded()) const SizedBox(height: 24),
                  // Amount Section - Enhanced
                  _isEditing
                      ? Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFF9E6), Color(0xFFFFFDD0)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFE5B4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFF9E6).withOpacity(0.6),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _transaction!['type']
                                                ?.toString()
                                                .toLowerCase() ==
                                            'income'
                                        ? Icons.arrow_circle_down_rounded
                                        : Icons.arrow_circle_up_rounded,
                                    color: const Color(0xFFF39C12),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _transaction!['type']
                                            ?.toString()
                                            .toUpperCase() ??
                                        'EXPENSE',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF999999),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Amount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF999999),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'RM',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFF39C12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _amountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            _transaction!['type']
                                                    ?.toString()
                                                    .toLowerCase() ==
                                                'income'
                                            ? const Color(0xFF52C77A)
                                            : const Color(0xFFE74C3C),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0.00',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        hintStyle: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey[300],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFF9E6), Color(0xFFFFFDD0)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFE5B4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFF9E6).withOpacity(0.6),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _transaction!['type']
                                                ?.toString()
                                                .toLowerCase() ==
                                            'income'
                                        ? Icons.arrow_circle_down_rounded
                                        : Icons.arrow_circle_up_rounded,
                                    color: const Color(0xFFF39C12),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _transaction!['type']
                                            ?.toString()
                                            .toUpperCase() ??
                                        'EXPENSE',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF999999),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'RM${(double.tryParse(_transaction!['amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      _transaction!['type']
                                              ?.toString()
                                              .toLowerCase() ==
                                          'income'
                                      ? const Color(0xFF52C77A)
                                      : const Color(0xFFE74C3C),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 16),
                  // Category Section - Enhanced with Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFE5B4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Category Icon
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFFE5B4),
                                  width: 1,
                                ),
                              ),
                              child: _transaction!['Category']?['icon'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        _transaction!['Category']?['icon'],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Icon(
                                                Icons.category_rounded,
                                                color: const Color(0xFFF39C12),
                                                size: 16,
                                              );
                                            },
                                      ),
                                    )
                                  : Icon(
                                      Icons.category_rounded,
                                      color: const Color(0xFFF39C12),
                                      size: 16,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF999999),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _transaction!['Category']?['name'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Account Section - Enhanced
                  _isEditing
                      ? GestureDetector(
                          onTap: _selectAccount,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9E6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFE5B4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFFF9E6,
                                  ).withOpacity(0.6),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Account',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF666666),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _accounts.firstWhere(
                                            (a) =>
                                                a['accountId'] ==
                                                _selectedAccountId,
                                            orElse: () => {
                                              'accountName': 'Select Account',
                                            },
                                          )['accountName'] ??
                                          'Select Account',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: const Color(0xFF666666),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFE5B4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Account Icon
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9E6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFFE5B4),
                                    width: 1,
                                  ),
                                ),
                                child:
                                    _transaction!['Account']?['iconImage'] !=
                                        null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          _transaction!['Account']['iconImage'],
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Icon(
                                                  Icons
                                                      .account_balance_wallet_rounded,
                                                  color: const Color(
                                                    0xFF666666,
                                                  ),
                                                  size: 18,
                                                );
                                              },
                                        ),
                                      )
                                    : Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: const Color(0xFF666666),
                                        size: 18,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Account',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF999999),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _transaction!['Account']?['accountName'] ??
                                        'N/A',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 16),
                  // Date Section - Enhanced
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFE5B4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: const Color(0xFFF39C12),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF999999),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatDateTime(_transaction!['date']),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Note - Enhanced
                  if (_transaction!['note'] != null &&
                      _transaction!['note'].toString().isNotEmpty)
                    _isEditing
                        ? _buildNoteField()
                        : Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFE5B4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.note_rounded,
                                      color: const Color(0xFFF39C12),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Note',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF999999),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _transaction!['note'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  const SizedBox(height: 32),
                  // Action Buttons - Enhanced
                  if (!_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Refund Button - Only show if not refunded and not income
                        if (!_isRefunded() &&
                            _transaction!['type']?.toString().toLowerCase() !=
                                'income')
                          GestureDetector(
                            onTap: _refundTransaction,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF52C77A),
                                        Color(0xFF3FA865),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF52C77A,
                                        ).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.undo_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Refund',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!_isRefunded() &&
                            _transaction!['type']?.toString().toLowerCase() !=
                                'income')
                          const SizedBox(width: 56),
                        // Delete Button - Always show
                        GestureDetector(
                          onTap: _deleteTransaction,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFE74C3C),
                                      Color(0xFFCB3421),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFE74C3C,
                                      ).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        // Cancel Button in Edit Mode
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _showCancelConfirmation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBCBCBC),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save Button in Edit Mode
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _updateTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA7E399),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE5B4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFF9E6).withOpacity(0.6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Note',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter note...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFFE5B4),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFF39C12),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
              hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
            ),
          ),
        ],
      ),
    );
  }
}
