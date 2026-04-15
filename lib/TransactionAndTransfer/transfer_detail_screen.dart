import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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
  bool _isEditing = false;
  bool _isSaving = false;

  // Edit controllers
  late TextEditingController _noteController;
  late TextEditingController _amountController;

  // Original values for comparison during edit
  String? _originalNote;
  String? _originalImage;
  double? _originalAmount;

  // Image editing
  XFile? _selectedImage;
  bool _imageDeleted = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _amountController = TextEditingController();
    _fetchTransferDetails();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
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
        _amountController.text = (response['amount'] ?? 0).toString();
        _originalNote = response['note'] ?? '';
        _originalImage = response['noteImage'];
        _originalAmount =
            double.tryParse(response['amount']?.toString() ?? '0') ?? 0;
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
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                        padding: EdgeInsets.zero,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        child: Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(
                            context,
                            true,
                          ); // Close transfer detail screen and return
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
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(
                            context,
                            true,
                          ); // Close transfer detail screen and return
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

  /// 📸 Show full-screen image viewer when user taps on receipt image
  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            color: Colors.black87,
            child: Column(
              children: [
                // Close Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: SizedBox()),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Full Image
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.grey[400],
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load image',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 📸 Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _selectedImage = image;
          _imageDeleted = false;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  /// 📸 Build image edit field with upload/delete options
  Widget _buildImageEditField() {
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
            'Transfer Receipt Image',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Image Preview or Upload Area
          if (!_imageDeleted &&
              (_selectedImage != null || _originalImage != null))
            Column(
              children: [
                // Show preview of selected image or original image
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFE5B4),
                      width: 1,
                    ),
                  ),
                  child: _selectedImage != null
                      ? FutureBuilder<Uint8List>(
                          future: _selectedImage!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _originalImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Colors.grey[400],
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_rounded),
                        label: const Text('Change Image'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF39C12),
                          side: const BorderSide(
                            color: Color(0xFFF39C12),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _imageDeleted = true;
                            _selectedImage = null;
                          });
                        },
                        icon: const Icon(Icons.delete_rounded),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // Upload new image area
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFE5B4),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      color: const Color(0xFFF39C12),
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to upload receipt image',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF39C12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build note field for editing
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

  /// Check if there are any changes
  bool _hasChanges() {
    final newAmount =
        double.tryParse(_amountController.text) ?? _originalAmount ?? 0;
    return _noteController.text != (_originalNote ?? '') ||
        newAmount != _originalAmount ||
        _selectedImage != null ||
        _imageDeleted;
  }

  /// Update transfer with new note, image, and amount
  Future<void> _updateTransfer() async {
    if (_transfer == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final newAmount =
          double.tryParse(_amountController.text) ?? _originalAmount ?? 0;
      final amountChanged = newAmount != _originalAmount;

      // Handle account balance adjustments if amount changed
      if (amountChanged) {
        final oldAmount = _originalAmount ?? 0;
        final difference = newAmount - oldAmount;

        // Get current balances for both accounts
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

        // Calculate new balances
        // If difference is positive: new transfer is larger, so subtract more from fromAccount, add more to toAccount
        // If difference is negative: new transfer is smaller, so add back to fromAccount, subtract from toAccount
        final newFromBalance = fromBalance - difference;
        final newToBalance = toBalance + difference;

        // Update both account balances
        await supabase
            .from('Account')
            .update({'balance': newFromBalance})
            .eq('accountId', _transfer!['fromAccountId']);

        await supabase
            .from('Account')
            .update({'balance': newToBalance})
            .eq('accountId', _transfer!['toAccountId']);
      }

      // Handle image upload/update
      String? newImageUrl = _originalImage;

      if (_imageDeleted) {
        // Image was deleted
        newImageUrl = null;
      } else if (_selectedImage != null) {
        // New image selected - upload to Supabase
        try {
          final fileExtension = _selectedImage!.path
              .split('.')
              .last
              .toLowerCase();
          final validExtension =
              ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension)
              ? fileExtension
              : 'jpg';
          final fileName =
              'TRNS_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.$validExtension';
          final filePath = 'transaction_image/$fileName';

          final fileBytes = await _selectedImage!.readAsBytes();
          await supabase.storage
              .from('images')
              .uploadBinary(filePath, fileBytes);

          newImageUrl = supabase.storage.from('images').getPublicUrl(filePath);
        } catch (e) {
          print('Error uploading image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading image: $e')),
            );
          }
          setState(() {
            _isSaving = false;
          });
          return;
        }
      }

      // Update transfer in database
      await supabase
          .from('Transfer')
          .update({
            'note': _noteController.text,
            'noteImage': newImageUrl,
            'amount': newAmount,
          })
          .eq('transferId', widget.transferId);

      setState(() {
        _transfer!['note'] = _noteController.text;
        _transfer!['noteImage'] = newImageUrl;
        _transfer!['amount'] = newAmount;
        _originalNote = _noteController.text;
        _originalImage = newImageUrl;
        _originalAmount = newAmount;
        _selectedImage = null;
        _imageDeleted = false;
        _isEditing = false;
        _isSaving = false;
      });

      if (mounted) {
        // Show success dialog with same theme as transaction detail
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
                      'Transfer Updated!',
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
                      'Your transfer note and image have been updated successfully.',
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
                          Navigator.pop(context);
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
      print('Error updating transfer: $e');
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating transfer: $e')));
      }
    }
  }

  /// Cancel editing
  void _cancelEdit() {
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
              const Text(
                'Discard Changes?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF39C12),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You have unsaved changes. Do you want to discard them?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Keep Editing'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _noteController.text = _originalNote ?? '';
                          _amountController.text = (_originalAmount ?? 0)
                              .toString();
                          _selectedImage = null;
                          _imageDeleted = false;
                          _isEditing = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Discard'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9E6),
        elevation: 0.5,
        leading: GestureDetector(
          onTap: () {
            if (_isEditing && _hasChanges()) {
              _cancelEdit();
            } else {
              Navigator.pop(context);
            }
          },
          child: Icon(
            _isEditing ? Icons.arrow_back_rounded : Icons.close_rounded,
            color: Colors.black,
            size: 26,
          ),
        ),
        title: Text(
          _isEditing ? 'Edit Transfer' : 'Transfer Details',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing && !_isRefunded())
            GestureDetector(
              onTap: () {
                setState(() {
                  _isEditing = true;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.edit_rounded,
                  color: const Color(0xFFF39C12),
                  size: 22,
                ),
              ),
            )
          else if (_isEditing && _isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_isEditing)
            GestureDetector(
              onTap: _updateTransfer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.check_rounded,
                  color: const Color(0xFFA7E399),
                  size: 24,
                ),
              ),
            ),
        ],
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
                                    Icons.currency_exchange_rounded,
                                    color: const Color(0xFFF39C12),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Amount (RM)',
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
                              TextField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  hintText: '0.00',
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
                                  hintStyle: const TextStyle(
                                    color: Color(0xFFCCCCCC),
                                  ),
                                  prefixText: 'RM ',
                                ),
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

                  // Note - Enhanced (Always show in edit mode, only if content in view mode)
                  if (_isEditing ||
                      (_transfer!['note'] != null &&
                          _transfer!['note'].toString().isNotEmpty))
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
                  // 📸 Image Section - Always show in edit mode, only if available in view mode
                  if (_isEditing ||
                      (_transfer!['noteImage'] != null &&
                          _transfer!['noteImage'].toString().isNotEmpty))
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        _isEditing
                            ? _buildImageEditField()
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
                                          Icons.image_rounded,
                                          color: const Color(0xFFF39C12),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Transfer Receipt Image',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF999999),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: () => _showFullImage(
                                        _transfer!['noteImage'],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _transfer!['noteImage'],
                                          fit: BoxFit.cover,
                                          height: 200,
                                          width: double.infinity,
                                          loadingBuilder:
                                              (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  height: 200,
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  height: 200,
                                                  color: Colors.grey[200],
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .image_not_supported_rounded,
                                                        color: Colors.grey[400],
                                                        size: 40,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Image failed to load',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[500],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  const SizedBox(height: 32),

                  // Action Buttons - Enhanced
                  if (!_isEditing)
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
