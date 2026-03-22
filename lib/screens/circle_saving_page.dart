import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

  List<Map<String, dynamic>> _accounts = [];
  String? _selectedSourceAccount;
  String? _selectedDestAccount;
  String _selectedCycleFrequency = 'Monthly';
  bool _enableAutoDeduction = false;

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

  Future<void> _fetchAccounts() async {
    try {
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('userId', widget.userId);

      setState(() {
        _accounts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching accounts: $e');
      if (mounted) {
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
              // Source Account Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSourceAccount,
                decoration: InputDecoration(
                  hintText: 'Source Account',
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
                items: _accounts.map((account) {
                  return DropdownMenuItem<String>(
                    value: account['accountId'],
                    child: Text(account['accountName'] ?? 'Unknown Account'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSourceAccount = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a source account';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Destination Account Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDestAccount,
                decoration: InputDecoration(
                  hintText: 'Dest Account',
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
                items: _accounts.map((account) {
                  return DropdownMenuItem<String>(
                    value: account['accountId'],
                    child: Text(account['accountName'] ?? 'Unknown Account'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDestAccount = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a destination account';
                  }
                  return null;
                },
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
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement saving suggestion logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Saving suggestion feature coming soon'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Saving Suggestion',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w600,
                        ),
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
