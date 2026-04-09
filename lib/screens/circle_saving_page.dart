import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'saving_goal_assistant_screen.dart';

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
      });
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

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () => onSelect(accountId),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.green.shade50
                                      : (isAccountUsed
                                            ? Colors.blue.shade50
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.green.shade400
                                        : (isAccountUsed
                                              ? Colors.blue.shade300
                                              : Colors.grey.shade300),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ..._buildSelectedAccountDisplay(
                                      sortedAccounts,
                                      accountId,
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      )
                                    else if (isAccountUsed && !isSourceAccount)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                        ),
                                        child: Tooltip(
                                          message: 'Already in use',
                                          child: Icon(
                                            Icons.info_outline,
                                            color: Colors.blue.shade400,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
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

  Future<void> _createSavingGoal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSourceAccount == null || _selectedDestAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both source and destination accounts'),
        ),
      );
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
        'cycleFrequency': cycleFrequencyDate?.toString().split(' ')[0],
        'icon': null,
        'sourceAcountId': _selectedSourceAccount,
        'destAccountId': _selectedDestAccount,
        'linkedAccountId': _selectedDestAccount,
        'userId': widget.userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving goal created successfully')),
        );
        Navigator.pop(context, true);
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
      backgroundColor: const Color(0xFFFFFFFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFB),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.black),
        ),
        title: const Text(
          'Circle Saving',
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
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Name',
                  filled: true,
                  fillColor: Colors.green.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              // Start Date Field
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Start Date',
                  filled: true,
                  fillColor: Colors.green.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
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
              TextFormField(
                controller: _endDateController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'End Date',
                  filled: true,
                  fillColor: Colors.green.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
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
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Amount',
                  filled: true,
                  fillColor: Colors.green.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
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
              // Cycle Frequency Section (Only for Circle Saving)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
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
                        fillColor: Colors.green.shade200,
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
                          activeColor: Colors.green,
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please create a ledger first before generating suggestions',
                        ),
                      ),
                    );
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
