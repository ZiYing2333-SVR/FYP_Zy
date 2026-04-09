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
              // Title
              const Text(
                'Confirm Refund',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF39C12),
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                'Are you sure you want to refund this transfer of RM${(_transfer!['amount'] ?? 0).toStringAsFixed(2)}?\n\nThis will add the amount back to ${_fromAccount?['accountName']} and deduct from ${_toAccount?['accountName']}.\n\nThe record will be marked as refunded but not deleted.',
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
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                  // Confirm Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7E399),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Confirm',
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
                      'Refund Successful!',
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
                      'RM${amount.toStringAsFixed(2)} has been refunded successfully.\n\nThe transfer record has been marked as refunded.',
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
                          Navigator.of(context).popUntil(
                            (route) =>
                                route.settings.name == '/' || route.isFirst,
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
    final isRefunded = _isRefunded();
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
                'Delete Transfer?',
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
                isRefunded
                    ? 'Are you sure you want to delete this transfer record? This will permanently delete the record. This action cannot be undone.'
                    : 'Are you sure you want to delete this transfer of RM${(_transfer!['amount'] ?? 0).toStringAsFixed(2)}? This will permanently delete the record and add the amount back to ${_fromAccount?['accountName']} and deduct from ${_toAccount?['accountName']}. This action cannot be undone.',
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
      final isRefunded = _isRefunded();

      if (!isRefunded) {
        // For non-refunded transfers, reverse the account balances
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
      }

      // 4. Permanently delete the transfer record
      await supabase
          .from('Transfer')
          .delete()
          .eq('transferId', widget.transferId);

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
                      'Transfer Deleted!',
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
                          ? 'Transfer record has been permanently deleted.'
                          : 'Transfer of RM${(double.tryParse(_transfer!['amount'].toString()) ?? 0).toStringAsFixed(2)} has been permanently deleted.\n\nThe amount has been reversed.',
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
                          Navigator.of(context).popUntil(
                            (route) =>
                                route.settings.name == '/' || route.isFirst,
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
          borderRadius: BorderRadius.circular(16),
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEFFD3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8C8), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFEFFD3).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Account Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E8C8), width: 1),
                ),
                child:
                    account['iconImage'] != null &&
                        account['iconImage'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          account['iconImage'],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.account_balance_wallet_rounded,
                              color: const Color(0xFF666666),
                              size: 16,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF666666),
                        size: 16,
                      ),
              ),
              const SizedBox(width: 10),
              // Account Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account['accountName'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        letterSpacing: 0.3,
                      ),
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
        elevation: 0.5,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close_rounded, color: Colors.black, size: 26),
        ),
        title: const Text(
          'Transfer Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Refunded Badge
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

                  // From Account
                  _buildAccountCard('From Account', _fromAccount),
                  const SizedBox(height: 20),

                  // Transfer Arrow - Enhanced
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFA7E399), Color(0xFF95D88A)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA7E399).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // To Account
                  _buildAccountCard('To Account', _toAccount),
                  const SizedBox(height: 28),

                  // Amount Section - Enhanced
                  Container(
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
                              Icons.currency_exchange_rounded,
                              color: const Color(0xFFF39C12),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Amount',
                              style: TextStyle(
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
                          'RM${(_transfer!['amount'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF39C12),
                            letterSpacing: -0.5,
                          ),
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
                          _formatDateTime(_transfer!['date']),
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
                  if (_transfer!['note'] != null &&
                      _transfer!['note'].toString().isNotEmpty)
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
                            _transfer!['note'] ?? '',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Refund Button - Only show if not refunded
                      if (!_isRefunded())
                        GestureDetector(
                          onTap: _isDeleting ? null : _refundTransfer,
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
                      if (!_isRefunded()) const SizedBox(width: 56),
                      // Delete Button - Always show
                      GestureDetector(
                        onTap: _isDeleting ? null : _deleteTransfer,
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
                  ),
                ],
              ),
            ),
    );
  }
}
