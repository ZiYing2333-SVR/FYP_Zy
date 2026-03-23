import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RefundScreen extends StatefulWidget {
  final String transactionId;
  final double amount;
  final String accountId;
  final String accountName;
  final String userId;

  const RefundScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.accountId,
    required this.accountName,
    required this.userId,
  });

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  bool _isLoading = false;

  Future<void> _confirmRefund() async {
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
          'Are you sure you want to refund RM${widget.amount.toStringAsFixed(2)} to ${widget.accountName}?',
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
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. Update the transaction refund status to true
      await supabase
          .from('Transaction')
          .update({'refund': true})
          .eq('transactionId', widget.transactionId);

      // 2. Update account balance
      final accountResponse = await supabase
          .from('Account')
          .select('balance')
          .eq('accountId', widget.accountId)
          .single();

      final currentBalance =
          double.tryParse(accountResponse['balance'].toString()) ?? 0;
      final newBalance = currentBalance + widget.amount;

      await supabase
          .from('Account')
          .update({'balance': newBalance})
          .eq('accountId', widget.accountId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refund of RM${widget.amount.toStringAsFixed(2)} processed successfully',
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
          _isLoading = false;
        });
      }
    }
  }

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
          'Refund',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Amount Display
                    Text(
                      'RM ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF52C77A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Refund Amount',
                      style: TextStyle(fontSize: 14, color: Color(0xFFBCBCBC)),
                    ),
                    const SizedBox(height: 32),
                    // Account Info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA7E399),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Receiving Refund',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.accountName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Refund Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmRefund,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF52C77A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Refund',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
