import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransferDetailScreen extends StatefulWidget {
  final String transferId;
  final String? userId;

  const TransferDetailScreen({
    super.key,
    required this.transferId,
    this.userId,
  });

  @override
  State<TransferDetailScreen> createState() => _TransferDetailScreenState();
}

class _TransferDetailScreenState extends State<TransferDetailScreen> {
  Map<String, dynamic>? _transfer;
  Map<String, dynamic>? _fromAccount;
  Map<String, dynamic>? _toAccount;
  bool _isLoading = true;
  bool _isDeleting = false;

  // Edit controllers
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _fetchTransferDetails();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransferDetails() async {
    try {
      final supabase = Supabase.instance.client;

      print('Fetching transfer with ID: ${widget.transferId}');

      final response = await supabase
          .from('Transfer')
          .select()
          .eq('transferId', widget.transferId)
          .single();

      print('Transfer fetched successfully: $response');

      // Fetch from and to account details
      final fromAccountResponse = await supabase
          .from('Account')
          .select('accountId, accountName, iconImage, balance')
          .eq('accountId', response['fromAccountId'])
          .single();

      final toAccountResponse = await supabase
          .from('Account')
          .select('accountId, accountName, iconImage, balance')
          .eq('accountId', response['toAccountId'])
          .single();

      setState(() {
        _transfer = response;
        _fromAccount = fromAccountResponse;
        _toAccount = toAccountResponse;
        _noteController.text = response['note'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching transfer details: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading transfer: $e')));
      }
    }
  }

  bool _isRefunded() => _transfer?['refund'] == true;

  Future<void> _refundTransfer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: const Text(
          'Confirm Refund',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF39C12),
          ),
        ),
        content: Text(
          'Are you sure you want to refund this transfer of RM${(_transfer!['amount'] ?? 0).toStringAsFixed(2)}?\n\nThis will add the amount back to ${_fromAccount?['accountName']} and deduct from ${_toAccount?['accountName']}.',
          style: const TextStyle(color: Color(0xFF666666)),
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
              'Confirm',
              style: TextStyle(color: Color(0xFFA7E399)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _processRefund();
    }
  }

  Future<void> _processRefund() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final amount = double.tryParse(_transfer!['amount'].toString()) ?? 0;

      // 1. Get current balances for both accounts
      final fromAccountResponse = await supabase
          .from('Account')
          .select('balance')
          .eq('accountId', _transfer!['fromAccountId'])
          .single();

      final toAccountResponse = await supabase
          .from('Account')
          .select('balance')
          .eq('accountId', _transfer!['toAccountId'])
          .single();

      final fromBalance =
          double.tryParse(fromAccountResponse['balance'].toString()) ?? 0;
      final toBalance =
          double.tryParse(toAccountResponse['balance'].toString()) ?? 0;

      // 2. Calculate new balances
      final newFromBalance = fromBalance + amount;
      final newToBalance = toBalance - amount;

      // 3. Update both account balances
      await supabase
          .from('Account')
          .update({'balance': newFromBalance})
          .eq('accountId', _transfer!['fromAccountId']);

      await supabase
          .from('Account')
          .update({'balance': newToBalance})
          .eq('accountId', _transfer!['toAccountId']);

      // 4. Mark transfer as refunded (don't delete)
      await supabase
          .from('Transfer')
          .update({'refund': true})
          .eq('transferId', widget.transferId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refund of RM${amount.toStringAsFixed(2)} processed successfully',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error processing refund: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing refund: $e')));
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _deleteTransfer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: const Text(
          'Confirm Delete',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE74C3C),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this transfer of RM${(_transfer!['amount'] ?? 0).toStringAsFixed(2)}?\n\nThis will add the amount back to ${_fromAccount?['accountName']} and deduct from ${_toAccount?['accountName']}.',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFE74C3C)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE74C3C)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _processDelete();
    }
  }

  Future<void> _processDelete() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final amount = double.tryParse(_transfer!['amount'].toString()) ?? 0;

      // 1. Get current balances for both accounts
      final fromAccountResponse = await supabase
          .from('Account')
          .select('balance')
          .eq('accountId', _transfer!['fromAccountId'])
          .single();

      final toAccountResponse = await supabase
          .from('Account')
          .select('balance')
          .eq('accountId', _transfer!['toAccountId'])
          .single();

      final fromBalance =
          double.tryParse(fromAccountResponse['balance'].toString()) ?? 0;
      final toBalance =
          double.tryParse(toAccountResponse['balance'].toString()) ?? 0;

      // 2. Calculate new balances
      final newFromBalance = fromBalance + amount;
      final newToBalance = toBalance - amount;

      // 3. Update both account balances
      await supabase
          .from('Account')
          .update({'balance': newFromBalance})
          .eq('accountId', _transfer!['fromAccountId']);

      await supabase
          .from('Account')
          .update({'balance': newToBalance})
          .eq('accountId', _transfer!['toAccountId']);

      // 4. Mark transfer as refunded (don't delete, same as refund)
      await supabase
          .from('Transfer')
          .update({'refund': true})
          .eq('transferId', widget.transferId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transfer deleted successfully. Amount reversed of RM${amount.toStringAsFixed(2)}',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error deleting transfer: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting transfer: $e')));
        setState(() {
          _isDeleting = false;
        });
      }
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

  Widget _buildAccountCard(String title, Map<String, dynamic>? account) {
    if (account == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          'Unknown Account',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Column(
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE5B4)),
          ),
          child: Row(
            children: [
              // Account Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFB0E0E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    account['iconImage'] != null &&
                        account['iconImage'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          account['iconImage'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.account_balance,
                              color: Colors.grey[600],
                              size: 20,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.account_balance,
                        color: Colors.grey[600],
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              // Account Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account['accountName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Balance: RM${(account['balance'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
          child: const Icon(Icons.close, color: Colors.black),
        ),
        title: const Text(
          'Transfer Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transfer == null
          ? Center(
              child: Text(
                'Transfer not found',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Refunded Badge
                  if (_isRefunded())
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5B4),
                        borderRadius: BorderRadius.circular(8),
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
                  if (_isRefunded()) const SizedBox(height: 20),

                  // From Account
                  _buildAccountCard('From Account', _fromAccount),
                  const SizedBox(height: 16),

                  // Transfer Icon/Arrow
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA7E399),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // To Account
                  _buildAccountCard('To Account', _toAccount),
                  const SizedBox(height: 20),

                  // Amount
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE5B4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'RM${(_transfer!['amount'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE5B4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _formatDateTime(_transfer!['date']),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note
                  if (_transfer!['note'] != null &&
                      _transfer!['note'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE5B4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Note',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _transfer!['note'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  // Action Buttons
                  if (!_isRefunded())
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Refund Button
                        GestureDetector(
                          onTap: _isDeleting ? null : _refundTransfer,
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
                          onTap: _isDeleting ? null : _deleteTransfer,
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
    );
  }
}
