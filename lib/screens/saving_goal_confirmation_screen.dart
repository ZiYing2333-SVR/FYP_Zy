import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/bank_icon_helper.dart';
import 'add_account_page1.dart';
import 'home_screen.dart';

class SavingGoalConfirmationScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> plan;
  final Map<String, dynamic> feasibility;
  final Map<String, dynamic> accountSuggestions;
  final List<Map<String, dynamic>> accounts;

  const SavingGoalConfirmationScreen({
    super.key,
    required this.userId,
    required this.plan,
    required this.feasibility,
    required this.accountSuggestions,
    required this.accounts,
  });

  @override
  State<SavingGoalConfirmationScreen> createState() =>
      _SavingGoalConfirmationScreenState();
}

class _SavingGoalConfirmationScreenState
    extends State<SavingGoalConfirmationScreen> {
  late String? _selectedSourceAccountId;
  late String? _selectedDestAccountId;
  bool _isCreating = false;
  List<Map<String, dynamic>> _sourceAccounts = [];
  List<Map<String, dynamic>> _destAccounts = [];
  bool _isLoadingAccounts = true;
  String _cycleType = 'monthly'; // 'monthly', 'weekly', 'daily'
  late TextEditingController _goalNameController;
  Set<String> _usedSourceAccountIds = {};
  Set<String> _usedDestAccountIds = {};

  @override
  void initState() {
    super.initState();
    _goalNameController = TextEditingController(
      text: widget.plan['savingGoalName'] ?? '',
    );
    _selectedSourceAccountId =
        widget.accountSuggestions['suggestedSourceAccountId'];
    _selectedDestAccountId =
        widget.accountSuggestions['suggestedDestAccountId'];
    _fetchFilteredAccounts();
  }

  @override
  void dispose() {
    _goalNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchFilteredAccounts() async {
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
      }
    }
  }

  Future<void> _createSavingGoal() async {
    // Validate goal name
    if (_goalNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a goal name')));
      return;
    }

    if (_selectedSourceAccountId == null || _selectedDestAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both source and destination accounts'),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

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

      // Get the goal name from user input
      final userEnteredGoalName = _goalNameController.text.trim();

      // Insert the saving goal with all required fields matching SavingGoal table schema
      await Supabase.instance.client.from('SavingGoal').insert({
        'goalId': goalId,
        'name': userEnteredGoalName,
        'type': 'intelligent',
        'targetAmount': widget.plan['targetAmount'],
        'currentAmount': 0,
        'startDate': widget.plan['startDate'],
        'endDate': widget.plan['endDate'],
        'description': 'Generated by Intelligent Savings Goal Assistant',
        'status': 'active',
        'cycleStatus': true,
        'cycleFrequency': _cycleType,
        'icon': null,
        'sourceAcountId': _selectedSourceAccountId,
        'destAccountId': _selectedDestAccountId,
        'linkedAccountId': _selectedDestAccountId,
        'userId': widget.userId,
      });

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
                      'Goal Created Successfully!',
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
                      'Your saving goal "${_goalNameController.text}" has been created. Start saving towards your goal!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
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
                          // Navigate to home screen (main page)
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) =>
                                  HomeScreen(userId: widget.userId),
                            ),
                            (route) => false,
                          );
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
                        child: const Text('View My Goals'),
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
      print('Error creating saving goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating goal: $e')));
      }
    } finally {
      setState(() {
        _isCreating = false;
      });
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
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          'Confirm Your Goal',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goal Name Input Field
            Text(
              'Goal Name',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _goalNameController,
              decoration: InputDecoration(
                hintText: 'Enter your goal name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a goal name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Goal Details Summary
            Text(
              'Goal Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              key: ValueKey(
                'goal_details_${_cycleType}',
              ), // Force rebuild when frequency changes
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Goal Name',
                    _goalNameController.text.isNotEmpty
                        ? _goalNameController.text
                        : (widget.plan['savingGoalName'] ?? ''),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Target Amount',
                    'RM${(widget.plan['targetAmount'] ?? 0).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Start Date', widget.plan['startDate'] ?? ''),
                  const SizedBox(height: 12),
                  _buildDetailRow('End Date', widget.plan['endDate'] ?? ''),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Duration',
                    _formatDuration(widget.plan['totalMonths'] ?? 0),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Saving Target ${_getCycleLabel(_cycleType)}',
                    _formatCurrency(
                      _calculateCycleAmount(
                        (widget.plan['plannedMonthlySaving'] ??
                                widget.plan['monthlyNetSavings'] ??
                                0)
                            .toDouble(),
                        _cycleType,
                      ),
                      'MYR',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Saving Frequency Selection (MOVED HERE - BEFORE Savings Suggestion)
            Text(
              'Saving Frequency',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButton<String>(
                value: _cycleType,
                isExpanded: true,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, size: 20),
                        SizedBox(width: 12),
                        Text('Monthly (30 days)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Row(
                      children: [
                        Icon(Icons.date_range, size: 20),
                        SizedBox(width: 12),
                        Text('Weekly (7 days)'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'daily',
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 20),
                        SizedBox(width: 12),
                        Text('Daily'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _cycleType = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            // Feasibility & Analysis Section (AFTER frequency selection for proper refresh)
            if (widget.feasibility.isNotEmpty)
              Container(
                key: ValueKey(
                  'feasibility_${_cycleType}',
                ), // Force complete rebuild when _cycleType changes
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Savings Suggestion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeasibilityBox(widget.feasibility),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            // Account Selection Section
            Text(
              'Select Accounts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            // Source Account Selection
            GestureDetector(
              onTap: _isLoadingAccounts ? null : _showSourceAccountsModal,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedSourceAccountId != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                    width: _selectedSourceAccountId != null ? 2 : 1,
                  ),
                  boxShadow: _selectedSourceAccountId != null
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
                    if (_selectedSourceAccountId != null) ...[
                      ..._buildSelectedAccountDisplay(
                        _sourceAccounts,
                        _selectedSourceAccountId,
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
            if (_selectedSourceAccountId != null)
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
                        color: _selectedDestAccountId != null
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                        width: _selectedDestAccountId != null ? 2 : 1,
                      ),
                      boxShadow: _selectedDestAccountId != null
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
                        if (_selectedDestAccountId != null) ...[
                          ..._buildSelectedAccountDisplay(
                            _destAccounts,
                            _selectedDestAccountId,
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
            // Info Box
            Container(
              key: ValueKey(
                'info_box_${_cycleType}',
              ), // Force rebuild when frequency changes
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.accountSuggestions['suggestedSourceAccountName'] !=
                              null
                          ? 'AI suggests ${widget.accountSuggestions['suggestedSourceAccountName']} as source and ${widget.accountSuggestions['suggestedDestAccountName']} as destination. You\'ve chosen to save ${_getCycleLabel(_cycleType)}.'
                          : 'Choose suitable accounts for your saving goal. You\'ve chosen to save ${_getCycleLabel(_cycleType)}.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (widget.feasibility['stage'] == 'impossible' || _isCreating)
                    ? null
                    : _createSavingGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.feasibility['stage'] == 'impossible'
                      ? Colors.grey
                      : Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Creating Goal...',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        widget.feasibility['stage'] == 'impossible'
                            ? 'Cannot Create - Goal Impossible'
                            : 'Create Goal',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            if (widget.feasibility['stage'] == 'impossible')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    'This goal is marked as IMPOSSIBLE with your current financial situation. '
                    'Please adjust your goal amount, extend the timeline, or increase your income before creating.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
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

  Widget _buildAccountCard(
    Map<String, dynamic> account,
    Function(String) onSelect,
    bool isSelected,
  ) {
    final accountId = account['accountId'] as String;
    final accountName = account['accountName'] as String? ?? 'Unnamed';
    final balance = ((account['balance'] ?? 0) as num).toDouble();
    final iconImage = account['iconImage'] as String?;
    final currencyId = account['currencyId'] as String? ?? 'MYR';

    return GestureDetector(
      onTap: () => onSelect(accountId),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Account Icon
            if (iconImage != null && iconImage.isNotEmpty)
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Image.network(
                  _getIconUrl(iconImage),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_wallet, size: 20),
                    );
                  },
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet, size: 20),
              ),
            // Account Name
            Text(
              accountName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Balance
            Text(
              _formatCurrency(balance, currencyId),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeasibilityBox(Map<String, dynamic> feasibility) {
    final feasibilityMessage = feasibility['feasibilityMessage'] ?? '';
    final analysis = feasibility['analysis'] ?? '';

    // Use the planned monthly saving from the plan (same as Goal Details), not from feasibility
    final requiredMonthlySavings =
        (widget.plan['plannedMonthlySaving'] ??
                widget.plan['monthlyNetSavings'] ??
                0)
            .toDouble();

    // Build clear suggestion message based on cycle type
    String adaptedMessage = '';

    if (_cycleType == 'monthly') {
      // For monthly: Show the original message as is
      adaptedMessage = feasibilityMessage;
    } else {
      // For weekly/daily: Show clear breakdown
      final cycleAmount = _calculateCycleAmount(
        requiredMonthlySavings,
        _cycleType,
      );
      final cycleLabel = _getCycleLabel(_cycleType);

      // Extract just the feasibility claim from original message (e.g., "This is comfortable...")
      String feasibilityReason = '';
      if (feasibilityMessage.contains('comfortable')) {
        feasibilityReason =
            'This is comfortable and within the recommended 20% saving rate.';
      } else if (feasibilityMessage.contains('exceeds')) {
        feasibilityReason =
            'This exceeds the recommended rate but is achievable within your net income.';
      } else if (feasibilityMessage.contains('cannot')) {
        feasibilityReason =
            'This goal cannot be achieved with your current financial situation.';
      }

      adaptedMessage =
          'Save ${_formatCurrency(cycleAmount, 'MYR')} $cycleLabel (${_formatCurrency(requiredMonthlySavings, 'MYR')}/month) to reach your goal. $feasibilityReason';
    }

    // Determine stage from analysis text (contains ACHIEVABLE, CHALLENGING, or IMPOSSIBLE)
    String stage = 'achievable';
    Color bgColor = Colors.green.shade50;
    Color borderColor = Colors.green.shade300;
    Color textColor = Colors.green.shade800;
    Color iconColor = Colors.green;
    IconData icon = Icons.check_circle;

    if (analysis.contains('IMPOSSIBLE')) {
      stage = 'impossible';
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
      textColor = Colors.red.shade800;
      iconColor = Colors.red;
      icon = Icons.cancel;
    } else if (analysis.contains('CHALLENGING')) {
      stage = 'challenging';
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      textColor = Colors.orange.shade800;
      iconColor = Colors.orange;
      icon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header with icon on the left
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status label
                    Text(
                      stage.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Feasibility message with cycle adaptation
                    Text(
                      adaptedMessage,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Analysis section
          if (analysis.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 12),
                const SizedBox(height: 12),
                Text(
                  'Analysis',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  analysis,
                  style: TextStyle(fontSize: 12, height: 1.5, color: textColor),
                ),
              ],
            ),
        ],
      ),
    );
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

  void _showSourceAccountsModal() {
    _showAccountsModal(
      'Select Source Account',
      _sourceAccounts,
      _selectedSourceAccountId,
      (accountId) {
        setState(() {
          _selectedSourceAccountId = accountId;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showDestAccountsModal() {
    _showAccountsModal(
      'Select Destination Account',
      _destAccounts,
      _selectedDestAccountId,
      (accountId) {
        setState(() {
          _selectedDestAccountId = accountId;
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
    // Determine which accounts are currently in use based on the title
    final isSourceAccountModal = title.contains('Source');
    final usedAccountIds = isSourceAccountModal
        ? _usedSourceAccountIds
        : _usedDestAccountIds;

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
                          final isAccountUsed = usedAccountIds.contains(
                            accountId,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: isAccountUsed
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
                                        ? Colors.green.shade50
                                        : (isAccountUsed
                                              ? Colors.grey.shade100
                                              : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.green.shade400
                                          : (isAccountUsed
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade300),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ..._buildSelectedAccountDisplay(
                                        accounts,
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

  /// Calculate the amount needed based on cycle type
  /// Converts monthly amount to weekly, daily, etc.
  double _calculateCycleAmount(double monthlySavings, String cycleType) {
    switch (cycleType) {
      case 'weekly':
        // Monthly / 4.33 (average weeks per month)
        return monthlySavings / 4.33;
      case 'daily':
        // Monthly / 30 (average days per month)
        return monthlySavings / 30;
      case 'monthly':
      default:
        return monthlySavings;
    }
  }

  /// Get cycle label for display
  String _getCycleLabel(String cycleType) {
    switch (cycleType) {
      case 'weekly':
        return 'per week';
      case 'daily':
        return 'per day';
      case 'monthly':
      default:
        return 'per month';
    }
  }

  /// Convert duration from months to weeks/days based on cycle type
  String _formatDuration(int totalMonths) {
    switch (_cycleType) {
      case 'weekly':
        final weeks = (totalMonths * 4.33).round();
        return '$weeks weeks';
      case 'daily':
        final days = totalMonths * 30;
        return '$days days';
      case 'monthly':
      default:
        return '$totalMonths months';
    }
  }
}
