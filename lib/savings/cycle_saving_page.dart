import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../AIFeatures/saving_goal_assistant_screen.dart';

class CircleSavingPage extends StatefulWidget {
  final String userId;

  const CircleSavingPage({super.key, required this.userId});

  @override
  State<CircleSavingPage> createState() => _CircleSavingPageState();
}

class _CircleSavingPageState extends State<CircleSavingPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _sourceAccountController;
  late TextEditingController _destAccountController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _amountController;

  List<Map<String, dynamic>> _sourceAccounts = [];
  List<Map<String, dynamic>> _destAccounts = [];
  String? _selectedSourceAccount;
  String? _selectedDestAccount;
  String _selectedCycleFrequency = 'Monthly';
  bool _enableAutoDeduction = true;
  bool _isLoadingAccounts = true;
  Set<String> _usedSourceAccountIds = {};
  Set<String> _usedDestAccountIds = {};
  String? _ledgerId;

  final List<String> _cycleFrequencies = ['Daily', 'Weekly', 'Monthly'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _sourceAccountController = TextEditingController();
    _destAccountController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _amountController = TextEditingController();
    _fetchLedgerId();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sourceAccountController.dispose();
    _destAccountController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchLedgerId() async {
    try {
      final response = await Supabase.instance.client
          .from('Ledger')
          .select('ledgerId')
          .eq('userId', widget.userId)
          .limit(1);

      if (response.isNotEmpty) {
        setState(() {
          _ledgerId = response[0]['ledgerId'] as String;
        });
      }
    } catch (e) {
      print('Error fetching ledger: $e');
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      // Fetch all saving goals for the user to identify used accounts
      final savingGoals = await Supabase.instance.client
          .from('SavingGoal')
          .select('sourceAcountId, destAccountId')
          .eq('userId', widget.userId);

      // Build sets of used account IDs
      final usedSourceIds = <String>{};
      final usedDestIds = <String>{};

      for (final goal in savingGoals as List) {
        final sourceId = goal['sourceAcountId'] as String?;
        final destId = goal['destAccountId'] as String?;
        if (sourceId != null) usedSourceIds.add(sourceId);
        if (destId != null) usedDestIds.add(destId);
      }

      // Fetch all accounts for the user
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('userId', widget.userId);

      if (mounted) {
        setState(() {
          // Filter source accounts: exclude Savings type
          _sourceAccounts = (response as List)
              .map((acc) => Map<String, dynamic>.from(acc as Map))
              .where((acc) => (acc['accountType'] as String?) != 'Savings')
              .toList();

          // Filter destination accounts: only Savings type
          _destAccounts = (response as List)
              .map((acc) => Map<String, dynamic>.from(acc as Map))
              .where((acc) => (acc['accountType'] as String?) == 'Savings')
              .toList();

          _usedSourceAccountIds = usedSourceIds;
          _usedDestAccountIds = usedDestIds;
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      print('Error fetching accounts: $e');
      if (mounted) {
        setState(() {
          _isLoadingAccounts = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading accounts: $e')));
      }
    }
  }

  Future<void> _selectDate(
    TextEditingController controller,
    bool isStartDate,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: isStartDate ? DateTime.now() : DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
        // Recalculate amount per cycle when date changes
      });
    }
  }

  double _calculateAmountPerCycle() {
    // Get the target amount
    final targetAmount = double.tryParse(_amountController.text) ?? 0;

    if (targetAmount <= 0 ||
        _startDateController.text.isEmpty ||
        _endDateController.text.isEmpty) {
      return 0;
    }

    try {
      // Parse dates
      final startDate = DateTime.parse(_startDateController.text);
      final endDate = DateTime.parse(_endDateController.text);

      // Calculate number of days
      final daysDifference =
          endDate.difference(startDate).inDays + 1; // +1 to include end date

      if (daysDifference <= 0) {
        return 0;
      }

      // Calculate based on cycle frequency
      double amountPerCycle = 0;
      switch (_selectedCycleFrequency) {
        case 'Daily':
          // Amount per day
          amountPerCycle = targetAmount / daysDifference;
          break;
        case 'Weekly':
          // Amount per week
          final weeks = daysDifference / 7;
          amountPerCycle = targetAmount / weeks;
          break;
        case 'Monthly':
          // Amount per month
          final months = daysDifference / 30;
          amountPerCycle = targetAmount / months;
          break;
      }

      return amountPerCycle;
    } catch (e) {
      print('Error calculating amount per cycle: $e');
      return 0;
    }
  }

  String _formatCurrency(double amount) {
    return 'RM${amount.toStringAsFixed(2)}';
  }

  String _getIconUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    return imagePath;
  }

  List<Widget> _buildSelectedAccountDisplay(
    List<Map<String, dynamic>> accounts,
    String? accountId,
  ) {
    if (accountId == null) return [];

    final account = accounts.firstWhere(
      (acc) => acc['accountId'] == accountId,
      orElse: () => {},
    );

    if (account.isEmpty) return [];

    final accountName = account['accountName'] as String? ?? 'Unnamed';
    final balance = ((account['balance'] ?? 0) as num).toDouble();
    final iconImage = account['iconImage'] as String?;

    return [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: iconImage != null && iconImage.isNotEmpty
            ? Image.network(
                _getIconUrl(iconImage),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.account_balance_wallet, size: 20);
                },
              )
            : const Icon(Icons.account_balance_wallet, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              accountName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _formatCurrency(balance),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    ];
  }

  void _showSourceAccountsModal() {
    _showAccountsModal(
      'Select Source Account',
      _sourceAccounts,
      _selectedSourceAccount,
      (accountId) {
        setState(() {
          _selectedSourceAccount = accountId;
        });
        Navigator.pop(context);
      },
      true, // isSourceAccount
    );
  }

  void _showDestAccountsModal() {
    _showAccountsModal(
      'Select Destination Account',
      _destAccounts,
      _selectedDestAccount,
      (accountId) {
        setState(() {
          _selectedDestAccount = accountId;
        });
        Navigator.pop(context);
      },
      false, // isSourceAccount
    );
  }

  void _showAccountsModal(
    String title,
    List<Map<String, dynamic>> accounts,
    String? selectedAccountId,
    Function(String) onSelect,
    bool isSourceAccount,
  ) {
    final usedAccountIds = isSourceAccount
        ? _usedSourceAccountIds
        : _usedDestAccountIds;

    // Sort accounts: unused first, then used (for destination accounts only)
    final sortedAccounts = List<Map<String, dynamic>>.from(accounts);
    if (!isSourceAccount) {
      sortedAccounts.sort((a, b) {
        final aUsed = usedAccountIds.contains(a['accountId']);
        final bUsed = usedAccountIds.contains(b['accountId']);
        if (aUsed == bUsed) return 0;
        return aUsed ? 1 : -1; // Used accounts last
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Accounts list
              Expanded(
                child: sortedAccounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No accounts available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: sortedAccounts.length,
                        itemBuilder: (context, index) {
                          final account = sortedAccounts[index];
                          final accountId = account['accountId'] as String;
                          final isSelected = accountId == selectedAccountId;
                          final isAccountUsed = usedAccountIds.contains(
                            accountId,
                          );
                          // Disable selection only for destination accounts that are already used
                          final isDisabled =
                              isAccountUsed && !isSelected && !isSourceAccount;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: isDisabled
                                  ? null
                                  : () => onSelect(accountId),
                              child: Opacity(
                                opacity: isDisabled ? 0.5 : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFF9E6)
                                        : (isDisabled
                                              ? Colors.grey.shade100
                                              : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFFFE5B4)
                                          : (isDisabled
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade300),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            ..._buildSelectedAccountDisplay(
                                              sortedAccounts,
                                              accountId,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFA7E399),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMissingFieldDialog(String fieldName) {
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
              border: Border.all(color: const Color(0xFFFFCDD2), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red[100],
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red[700],
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                // Error title
                const Text(
                  'Missing Field',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF39C12),
                  ),
                ),
                const SizedBox(height: 12),
                // Error message
                Text(
                  fieldName == 'accounts'
                      ? 'Please select both source and destination accounts to continue.'
                      : 'Please create a ledger first before generating suggestions.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // OK button
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog() {
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
                  child: const Icon(Icons.check, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                // Success title
                const Text(
                  'Saving Goal Created Successfully!',
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
                  'Your saving goal has been created successfully.',
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
                      Navigator.pop(context, true); // Go back to savings page
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

  Future<void> _createSavingGoal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSourceAccount == null || _selectedDestAccount == null) {
      _showMissingFieldDialog('accounts');
      return;
    }

    try {
      // Generate sequential ID: SAVG+userId+sequential number
      final response = await Supabase.instance.client
          .from('SavingGoal')
          .select('goalId')
          .eq('userId', widget.userId)
          .order('goalId', ascending: false)
          .limit(1);

      int nextNumber = 1;
      if (response.isNotEmpty) {
        final lastGoalId = response[0]['goalId'] as String;
        // Extract the sequential number from the last goal ID
        // Format: SAVG{userId}{4-digit-number}
        final prefixLength = 'SAVG'.length + widget.userId.length;
        if (lastGoalId.length > prefixLength) {
          final lastNumberStr = lastGoalId.substring(prefixLength);
          final lastNumber = int.tryParse(lastNumberStr) ?? 0;
          nextNumber = lastNumber + 1;
        }
      }
      final goalId =
          'SAVG${widget.userId}${nextNumber.toString().padLeft(4, '0')}';

      print('Generated Goal ID: $goalId');

      // Parse cycle frequency to date (you may need to adjust this based on your needs)
      DateTime? cycleFrequencyDate;
      if (_enableAutoDeduction) {
        final now = DateTime.now();
        switch (_selectedCycleFrequency) {
          case 'Daily':
            cycleFrequencyDate = now.add(const Duration(days: 1));
            break;
          case 'Weekly':
            cycleFrequencyDate = now.add(const Duration(days: 7));
            break;
          case 'Monthly':
            cycleFrequencyDate = DateTime(now.year, now.month + 1, now.day);
            break;
        }
      }

      await Supabase.instance.client.from('SavingGoal').insert({
        'goalId': goalId,
        'name': _nameController.text,
        'type': 'cycle',
        'targetAmount': double.parse(_amountController.text),
        'currentAmount': 0,
        'startDate': _startDateController.text,
        'endDate': _endDateController.text,
        'description': '',
        'status': 'active',
        'cycleStatus': _enableAutoDeduction,
        'cycleFrequency': _selectedCycleFrequency.toLowerCase(),
        'icon': null,
        'sourceAcountId': _selectedSourceAccount,
        'destAccountId': _selectedDestAccount,
        'linkedAccountId': _selectedDestAccount,
        'userId': widget.userId,
        'amountPerCycle': _calculateAmountPerCycle(),
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      print('Error creating saving goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating goal: $e')));
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
          child: const Icon(Icons.close, color: Colors.black),
        ),
        title: const Text(
          'Cycle Saving',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Name Field
              Text(
                'Saving Goal Name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter goal name',
                  filled: true,
                  fillColor: const Color(0xFFFFF9E6),
                  prefixIcon: const Icon(
                    Icons.savings,
                    color: Color(0xFFA7E399),
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFA7E399),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Source Account Selection
              GestureDetector(
                onTap: _isLoadingAccounts ? null : _showSourceAccountsModal,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedSourceAccount != null
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                      width: _selectedSourceAccount != null ? 2 : 1,
                    ),
                    boxShadow: _selectedSourceAccount != null
                        ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      // Source account icon and info
                      if (_selectedSourceAccount != null) ...[
                        ..._buildSelectedAccountDisplay(
                          _sourceAccounts,
                          _selectedSourceAccount,
                        ),
                      ] else
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Source Account (Transfer from)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isLoadingAccounts
                                    ? 'Loading...'
                                    : 'Tap to select',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Destination Account Selection - Only show if source is selected
              if (_selectedSourceAccount != null)
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: _isLoadingAccounts ? null : _showDestAccountsModal,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedDestAccount != null
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                          width: _selectedDestAccount != null ? 2 : 1,
                        ),
                        boxShadow: _selectedDestAccount != null
                            ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.1),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          // Destination account icon and info
                          if (_selectedDestAccount != null) ...[
                            ..._buildSelectedAccountDisplay(
                              _destAccounts,
                              _selectedDestAccount,
                            ),
                          ] else
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Destination Account (Save to)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isLoadingAccounts
                                        ? 'Loading...'
                                        : 'Tap to select',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // Start Date Field
              Text(
                'Start Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Select start date',
                  filled: true,
                  fillColor: const Color(0xFFFFF9E6),
                  prefixIcon: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFFA7E399),
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFA7E399),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onTap: () => _selectDate(_startDateController, true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a start date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // End Date Field
              Text(
                'End Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _endDateController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Select end date',
                  filled: true,
                  fillColor: const Color(0xFFFFF9E6),
                  prefixIcon: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFFA7E399),
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFA7E399),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onTap: () => _selectDate(_endDateController, false),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an end date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Amount Field
              Text(
                'Target Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  filled: true,
                  fillColor: const Color(0xFFFFF9E6),
                  prefixIcon: const Icon(
                    Icons.attach_money,
                    color: Color(0xFFA7E399),
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE5B4),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFA7E399),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onChanged: (value) {
                  setState(() {
                    // Trigger recalculation when amount changes
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Amount Per Cycle Display Field
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount per ${_selectedCycleFrequency.toLowerCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(_calculateAmountPerCycle()),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF39C12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Cycle Frequency Section (Only for Circle Saving)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE5B4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cycle Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Cycle Frequency Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCycleFrequency,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Cycle Frequency',
                        filled: true,
                        fillColor: const Color(0xFFFFF9E6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: _cycleFrequencies.map((frequency) {
                        return DropdownMenuItem<String>(
                          value: frequency,
                          child: Text(frequency),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCycleFrequency = value ?? 'Monthly';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Auto Deduction Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enable Auto Deduction',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Switch(
                          value: _enableAutoDeduction,
                          onChanged: (value) {
                            setState(() {
                              _enableAutoDeduction = value;
                            });
                          },
                          activeColor: const Color(0xFFA7E399),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Saving Suggestion Button
              GestureDetector(
                onTap: () async {
                  // Validate ledger exists
                  if (_ledgerId == null || _ledgerId!.isEmpty) {
                    _showMissingFieldDialog('ledger');
                    return;
                  }
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavingGoalAssistantScreen(
                        userId: widget.userId,
                        ledgerId: _ledgerId!,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saving Suggestion',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                'Get AI-powered recommendations',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createSavingGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
