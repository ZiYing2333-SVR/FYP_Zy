import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/bank_icon_helper.dart';
import 'saving_goal_assistant_screen.dart';

class FreeSavingPage extends StatefulWidget {
  final String userId;

  const FreeSavingPage({super.key, required this.userId});

  @override
  State<FreeSavingPage> createState() => _FreeSavingPageState();
}

class _FreeSavingPageState extends State<FreeSavingPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;

  List<Map<String, dynamic>> _destAccounts = [];
  String? _selectedDestAccount;
  bool _isLoadingAccounts = true;
  Set<String> _usedDestAccountIds = {};
  String? _ledgerId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();
    _fetchLedgerId();
    _fetchFilteredAccounts();
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _fetchFilteredAccounts() async {
    try {
      // Fetch all saving goals for the user to identify used accounts
      final savingGoals = await Supabase.instance.client
          .from('SavingGoal')
          .select('sourceAcountId, destAccountId')
          .eq('userId', widget.userId);

      // Build set of used destination account IDs
      final usedDestIds = <String>{};

      for (final goal in savingGoals as List) {
        final destId = goal['destAccountId'] as String?;
        if (destId != null) usedDestIds.add(destId);
      }

      // Fetch all accounts for the user
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('userId', widget.userId);

      if (mounted) {
        setState(() {
          // Filter destination accounts: only Savings type
          _destAccounts = (response as List)
              .map((acc) => Map<String, dynamic>.from(acc as Map))
              .where((acc) => (acc['accountType'] as String?) == 'Savings')
              .toList();

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
      });
    }
  }

  String _getIconUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    } else if (imagePath.startsWith('AccountLogo/')) {
      return BankIconHelper.getBankIconUrl(imagePath);
    }
    return imagePath;
  }

  String _formatCurrency(double amount, String currencyId) {
    return 'RM${amount.toStringAsFixed(2)}';
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
    final currencyId = account['currencyId'] as String? ?? 'MYR';

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
              _formatCurrency(balance, currencyId),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    ];
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
    );
  }

  void _showAccountsModal(
    String title,
    List<Map<String, dynamic>> accounts,
    String? selectedAccountId,
    Function(String) onSelect,
  ) {
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
                child: accounts.isEmpty
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
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          final accountId = account['accountId'] as String;
                          final isSelected = accountId == selectedAccountId;
                          final isAccountUsed = _usedDestAccountIds.contains(
                            accountId,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: isAccountUsed && !isSelected
                                  ? null
                                  : () => onSelect(accountId),
                              child: Opacity(
                                opacity: isAccountUsed && !isSelected
                                    ? 0.5
                                    : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFF9E6)
                                        : (isAccountUsed && !isSelected
                                              ? Colors.grey.shade100
                                              : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFFFE5B4)
                                          : (isAccountUsed && !isSelected
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
                                              accounts,
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
                  fieldName == 'account'
                      ? 'Please select a destination account to continue.'
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

    if (_selectedDestAccount == null) {
      _showMissingFieldDialog('account');
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

      await Supabase.instance.client.from('SavingGoal').insert({
        'goalId': goalId,
        'name': _nameController.text,
        'type': 'free',
        'targetAmount': double.parse(_amountController.text),
        'currentAmount': 0,
        'startDate': null,
        'endDate': null,
        'description': '',
        'status': 'active',
        'cycleStatus': false,
        'cycleFrequency': null,
        'icon': null,
        'sourceAcountId': null,
        'destAccountId': _selectedDestAccount,
        'linkedAccountId': _selectedDestAccount,
        'userId': widget.userId,
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
          'Free Saving',
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
              // Destination Account Selection
              Text(
                'Destination Account (Save to)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isLoadingAccounts ? null : _showDestAccountsModal,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedDestAccount != null
                          ? const Color(0xFFFFE5B4)
                          : Colors.grey.shade300,
                      width: _selectedDestAccount != null ? 2 : 1,
                    ),
                    boxShadow: _selectedDestAccount != null
                        ? [
                            BoxShadow(
                              color: const Color(0xFFA7E399).withOpacity(0.1),
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
                                'Save to',
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
                    // Trigger update when amount changes
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
              const SizedBox(height: 24),
              // Saving Suggestion Button
              GestureDetector(
                onTap: () async {
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
                    color: const Color(0xFFFFF9E6),
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
                                'Get personalized suggestions',
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
