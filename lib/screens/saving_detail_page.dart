import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transfer_detail_screen.dart';

class SavingDetailPage extends StatefulWidget {
  final String goalId;
  final String userId;

  const SavingDetailPage({
    super.key,
    required this.goalId,
    required this.userId,
  });

  @override
  State<SavingDetailPage> createState() => _SavingDetailPageState();
}

class _SavingDetailPageState extends State<SavingDetailPage> {
  Map<String, dynamic>? _savingGoal;
  Map<String, dynamic>? _destAccount;
  Map<String, dynamic>? _sourceAccount;
  Map<String, dynamic>? _linkedAccount;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transferRecords = [];
  bool _isLoadingTransfers = true;

  // Edit mode variables
  bool _isEditMode = false;
  late TextEditingController _goalNameController;
  late bool _originalCycleStatus;
  late bool _newCycleStatus;
  late String _originalGoalName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _goalNameController = TextEditingController();
    _fetchSavingDetails();
  }

  @override
  void dispose() {
    _goalNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchSavingDetails() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch saving goal details
      final goalResponse = await Supabase.instance.client
          .from('SavingGoal')
          .select()
          .eq('goalId', widget.goalId)
          .single();

      setState(() {
        _savingGoal = goalResponse;
        // Initialize edit mode values
        _goalNameController.text = goalResponse['name'] ?? '';
        _originalGoalName = goalResponse['name'] ?? '';
        _originalCycleStatus = goalResponse['cycleStatus'] ?? false;
        _newCycleStatus = goalResponse['cycleStatus'] ?? false;
      });

      // Fetch related account details
      if (_savingGoal != null) {
        final futures = <Future<void>>[];

        if (_savingGoal!['destAccountId'] != null) {
          futures.add(_fetchAccount(_savingGoal!['destAccountId'] as String));
        }
        if (_savingGoal!['sourceAcountId'] != null) {
          futures.add(_fetchAccount(_savingGoal!['sourceAcountId'] as String));
        }
        if (_savingGoal!['linkedAccountId'] != null) {
          futures.add(_fetchAccount(_savingGoal!['linkedAccountId'] as String));
        }

        if (futures.isNotEmpty) {
          await Future.wait(futures);
        }

        // Fetch transfer records after accounts are loaded
        await _fetchTransferRecords();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching saving details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTransferRecords() async {
    try {
      if (_savingGoal == null || _savingGoal!['destAccountId'] == null) {
        setState(() {
          _transferRecords = [];
          _isLoadingTransfers = false;
        });
        return;
      }

      final destAccountId = _savingGoal!['destAccountId'];

      // Fetch all transfers where toAccountId matches the destination account
      final transfers = await Supabase.instance.client
          .from('Transfer')
          .select()
          .eq('toAccountId', destAccountId)
          .order('date', ascending: false);

      // Fetch account details for from accounts
      final accountIds = <String>{};
      for (var transfer in transfers) {
        if (transfer['fromAccountId'] != null) {
          accountIds.add(transfer['fromAccountId'] as String);
        }
      }

      // Batch fetch all accounts
      Map<String, dynamic> accountsMap = {};
      if (accountIds.isNotEmpty) {
        final accountsList = await Supabase.instance.client
            .from('Account')
            .select()
            .inFilter('accountId', accountIds.toList());

        for (var account in accountsList) {
          accountsMap[account['accountId']] = account;
        }
      }

      // Enrich transfer records with account data
      final enrichedTransfers = <Map<String, dynamic>>[];
      for (var transfer in transfers) {
        final enriched = Map<String, dynamic>.from(transfer);
        enriched['Account!fromAccountId'] =
            accountsMap[transfer['fromAccountId']] ?? {};
        enriched['Account!toAccountId'] = _destAccount ?? {};
        enrichedTransfers.add(enriched);
      }

      setState(() {
        _transferRecords = enrichedTransfers;
        _isLoadingTransfers = false;
      });
    } catch (e) {
      print('Error fetching transfer records: $e');
      setState(() {
        _isLoadingTransfers = false;
      });
    }
  }

  Future<void> _fetchAccount(String accountId) async {
    try {
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('accountId', accountId)
          .single();

      setState(() {
        if (_savingGoal != null) {
          if (accountId == _savingGoal!['destAccountId']) {
            _destAccount = response;
          } else if (accountId == _savingGoal!['sourceAcountId']) {
            _sourceAccount = response;
          } else if (accountId == _savingGoal!['linkedAccountId']) {
            _linkedAccount = response;
          }
        }
      });
    } catch (e) {
      print('Error fetching account $accountId: $e');
    }
  }

  String _formatCurrency(dynamic value) {
    final amount = (value ?? 0).toDouble();
    return 'RM${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  bool _hasChanges() {
    return _goalNameController.text != _originalGoalName ||
        _newCycleStatus != _originalCycleStatus;
  }

  void _toggleEditMode() {
    if (_isEditMode && _hasChanges()) {
      _showDiscardConfirmation();
    } else {
      setState(() {
        if (_isEditMode) {
          // Reset values when exiting edit mode without saving
          _goalNameController.text = _originalGoalName;
          _newCycleStatus = _originalCycleStatus;
        }
        _isEditMode = !_isEditMode;
      });
    }
  }

  void _showDiscardConfirmation() {
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
                      // Reset values
                      _goalNameController.text = _originalGoalName;
                      _newCycleStatus = _originalCycleStatus;
                      _isEditMode = false;
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

  Future<void> _saveChanges() async {
    if (_goalNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a goal name')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await Supabase.instance.client
          .from('SavingGoal')
          .update({
            'name': _goalNameController.text,
            'cycleStatus': _newCycleStatus,
          })
          .eq('goalId', widget.goalId);

      if (mounted) {
        setState(() {
          _originalGoalName = _goalNameController.text;
          _originalCycleStatus = _newCycleStatus;
          _isSaving = false;
        });

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
                      'Saving Goal Updated Successfully!',
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
                      'Your saving goal has been updated successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 24),
                    // Done button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          _fetchSavingDetails(); // Refresh data in real time
                          setState(() {
                            _isEditMode = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA7E399),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating saving goal: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildAccountCard(String title, Map<String, dynamic>? account) {
    if (account == null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFFFE5B4), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFFFFF9E6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFFFE5B4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Account Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: account['iconImage'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        account['iconImage'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.account_balance_wallet,
                            color: Colors.grey.shade600,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.account_balance_wallet,
                      color: Colors.grey.shade600,
                    ),
            ),
            const SizedBox(width: 12),
            // Account Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account['accountName'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(account['balance']),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferRecord(Map<String, dynamic> transfer, int index) {
    final amount = double.tryParse(transfer['amount'].toString()) ?? 0;
    final note = transfer['note'] ?? '';
    final isRefunded = transfer['refund'] == true;
    final fromAccount = transfer['Account!fromAccountId'] ?? {};
    final toAccount = transfer['Account!toAccountId'] ?? {};
    final isLastItem = index == _transferRecords.length - 1;

    // Parse date
    DateTime? transferDate;
    if (transfer['date'] != null) {
      try {
        transferDate = DateTime.parse(transfer['date'].toString());
      } catch (e) {
        transferDate = null;
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            final transferId = transfer['transferId'] as String;
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransferDetailScreen(
                  transferId: transferId,
                  userId: widget.userId,
                ),
              ),
            );
            if (result == true) {
              _fetchTransferRecords();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Transfer Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.compare_arrows,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                // Transfer Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Transfer',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (transferDate != null)
                            Text(
                              _formatDate(_formatDateOnly(transferDate)),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFBCBCBC),
                              ),
                            ),
                        ],
                      ),
                      if (note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            note,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFBCBCBC),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount and Account Icons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '-RM${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE74C3C),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Transfer account icons
                        _buildTransferAccountIcons(fromAccount, toAccount),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Refund Badge
                    if (isRefunded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5B4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'REFUNDED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE74C3C),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Divider
        if (!isLastItem)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(
              color: const Color(0xFFFFE5B4),
              height: 1,
              thickness: 1,
            ),
          ),
      ],
    );
  }

  Widget _buildTransferAccountIcons(
    Map<String, dynamic> fromAccount,
    Map<String, dynamic> toAccount,
  ) {
    final fromIcon = fromAccount['iconImage'] ?? '';
    final toIcon = toAccount['iconImage'] ?? '';

    return Row(
      children: [
        // From account icon
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFE5B4), width: 1),
          ),
          child: fromIcon.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    fromIcon,
                    fit: BoxFit.scaleDown,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance, size: 12),
                      );
                    },
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance, size: 12),
                ),
        ),
        const SizedBox(width: 4),
        // To account icon
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFE5B4), width: 1),
          ),
          child: toIcon.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    toIcon,
                    fit: BoxFit.scaleDown,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance, size: 12),
                      );
                    },
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance, size: 12),
                ),
        ),
      ],
    );
  }

  String _formatDateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildFreeSavingDetail() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE5B4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _savingGoal!['name'] ?? 'Unnamed Goal',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _formatCurrency(_savingGoal!['targetAmount']),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _formatCurrency(_destAccount?['balance'] ?? 0.0),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            (_savingGoal!['status'] ?? 'active')
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color:
                                  (_savingGoal!['status'] == 'inactive'
                                          ? Colors.grey
                                          : Colors.green)
                                      .shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:
                          (_destAccount?['balance'] ?? 0) /
                          (_savingGoal!['targetAmount'] ?? 1),
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final destBalance = _destAccount?['balance'] ?? 0;
                      final targetAmount = _savingGoal!['targetAmount'] ?? 1;
                      final progressPercentage =
                          ((destBalance / targetAmount) * 100)
                              .clamp(0, 100)
                              .toStringAsFixed(1);

                      return Text(
                        '$progressPercentage% Complete',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Destination Account Section
            Text(
              'Destination Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 12),
            _buildAccountCard('Destination Account', _destAccount),
            const SizedBox(height: 24),
            // Transfer Records Section
            Text(
              'Transfer Records',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingTransfers)
              const Center(child: CircularProgressIndicator())
            else if (_transferRecords.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFFFFF9E6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFFFE5B4), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No transfer records',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFFFFF9E6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFFFE5B4), width: 1),
                ),
                child: Column(
                  children: _transferRecords
                      .asMap()
                      .entries
                      .map(
                        (entry) => _buildTransferRecord(entry.value, entry.key),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleSavingDetail() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE5B4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _savingGoal!['name'] ?? 'Unnamed Goal',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _formatCurrency(_savingGoal!['targetAmount']),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _formatCurrency(_destAccount?['balance'] ?? 0.0),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            (_savingGoal!['status'] ?? 'active')
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color:
                                  (_savingGoal!['status'] == 'inactive'
                                          ? Colors.grey
                                          : Colors.green)
                                      .shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:
                          (_destAccount?['balance'] ?? 0) /
                          (_savingGoal!['targetAmount'] ?? 1),
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final destBalance = _destAccount?['balance'] ?? 0;
                      final targetAmount = _savingGoal!['targetAmount'] ?? 1;
                      final progressPercentage =
                          ((destBalance / targetAmount) * 100)
                              .clamp(0, 100)
                              .toStringAsFixed(1);

                      return Text(
                        '$progressPercentage% Complete',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Account Information Section
            Text(
              'Account Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 12),
            _buildAccountCard('Source Account', _sourceAccount),
            _buildAccountCard('Destination Account', _destAccount),
            const SizedBox(height: 24),
            // Cycle Details Section
            Text(
              'Cycle Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailCard(
              'Start Date',
              _formatDate(_savingGoal!['startDate']),
            ),
            _buildDetailCard('End Date', _formatDate(_savingGoal!['endDate'])),
            _buildDetailCard(
              'Cycle Frequency',
              _savingGoal!['cycleFrequency'] ?? 'N/A',
            ),
            _buildDetailCard(
              'Auto Deduction Status',
              _savingGoal!['cycleStatus'] == true ? 'Active' : 'Inactive',
            ),
            const SizedBox(height: 24),
            // Transfer Records Section
            Text(
              'Transfer Records',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoadingTransfers)
              const Center(child: CircularProgressIndicator())
            else if (_transferRecords.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFFFFF9E6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFFFE5B4), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No transfer records',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFFFFF9E6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFFFE5B4), width: 1),
                ),
                child: Column(
                  children: _transferRecords
                      .asMap()
                      .entries
                      .map(
                        (entry) => _buildTransferRecord(entry.value, entry.key),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFFFFF9E6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFFFE5B4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditMode(bool isCycleSaving) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal Name Edit
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Goal Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8D5F2), width: 2),
              ),
              child: TextField(
                controller: _goalNameController,
                decoration: const InputDecoration(
                  hintText: 'Enter goal name',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFC8A5D8)),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Auto Deduction Toggle (only for cycle savings)
            if (isCycleSaving) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto Deduction',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Enable automatic deduction on cycle',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _newCycleStatus,
                      onChanged: (bool value) {
                        setState(() {
                          _newCycleStatus = value;
                        });
                      },
                      activeColor: const Color(0xFFA7E399),
                      inactiveThumbColor: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ] else
              const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA7E399),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  disabledBackgroundColor: const Color(0xFFD3F8D3),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        if (_hasChanges()) {
                          _showDiscardConfirmation();
                        } else {
                          setState(() {
                            _isEditMode = false;
                          });
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCycleSaving =
        _savingGoal?['type']?.toString().toLowerCase() == 'cycle';

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (_isEditMode && _hasChanges()) {
              _showDiscardConfirmation();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isEditMode
              ? '${isCycleSaving ? 'Cycle' : 'Free'} Saving Edit'
              : '${isCycleSaving ? 'Cycle' : 'Free'} Saving Details',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black87),
              onPressed: _toggleEditMode,
              tooltip: 'Edit',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savingGoal == null
          ? const Center(child: Text('Saving goal not found'))
          : _isEditMode
          ? _buildEditMode(isCycleSaving)
          : isCycleSaving
          ? _buildCycleSavingDetail()
          : _buildFreeSavingDetail(),
    );
  }
}
