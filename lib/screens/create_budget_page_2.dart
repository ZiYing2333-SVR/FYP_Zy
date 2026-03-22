import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateBudgetPage2 extends StatefulWidget {
  final String userId;
  final String? ledgerId;
  final String? categoryId;
  final String? accountId;

  const CreateBudgetPage2({
    super.key,
    required this.userId,
    this.ledgerId,
    this.categoryId,
    this.accountId,
  });

  @override
  State<CreateBudgetPage2> createState() => _CreateBudgetPage2State();
}

class _CreateBudgetPage2State extends State<CreateBudgetPage2> {
  final TextEditingController _budgetAmountController = TextEditingController();
  String _selectedCycleType = 'Month';
  bool _rolloverStatus = false;
  bool _isSaving = false;

  final List<String> _cycleTypes = ['Day', 'Week', 'Month', 'Year'];

  @override
  void dispose() {
    _budgetAmountController.dispose();
    super.dispose();
  }

  String _determineBudgetType() {
    if (widget.ledgerId != null) {
      return 'ledger';
    } else if (widget.categoryId != null) {
      return 'category';
    } else if (widget.accountId != null) {
      return 'account';
    }
    return 'unknown';
  }

  Future<String> _generateBudgetId() async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch all budgets for this user and sort to find the latest budgetId
      final response = await supabase
          .from('Budget')
          .select('budgetId')
          .eq('userId', widget.userId)
          .order('budgetId', ascending: false)
          .limit(1);

      int nextNumber = 1;

      if (response.isNotEmpty && response[0]['budgetId'] != null) {
        final lastBudgetId = response[0]['budgetId'] as String;
        // Extract number from budgetId (e.g., "BUD{userId}0001" -> 1)
        final numberString = lastBudgetId.replaceAll('BUD${widget.userId}', '');
        try {
          nextNumber = int.parse(numberString) + 1;
        } catch (e) {
          nextNumber = 1;
        }
      }

      // Generate new budgetId with zero-padding (e.g., "BUD{userId}0001", "BUD{userId}0002")
      return 'BUD${widget.userId}${nextNumber.toString().padLeft(4, '0')}';
    } catch (error) {
      // If error occurs, start from 0001
      return 'BUD${widget.userId}0001';
    }
  }

  Future<void> _saveBudget() async {
    // Validate input
    if (_budgetAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter budget amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final budgetId = await _generateBudgetId();
      final budgetType = _determineBudgetType();

      await Supabase.instance.client.from('Budget').insert({
        'budgetId': budgetId,
        'type': budgetType,
        'amount': double.parse(_budgetAmountController.text),
        'cycleType': _selectedCycleType.toLowerCase(),
        'rolloverStatus': _rolloverStatus,
        'reuseStatus': false,
        'ledgerId': widget.ledgerId,
        'categoryId': widget.categoryId,
        'accountId': widget.accountId,
        'userId': widget.userId,
      });

      if (mounted) {
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
                      'Budget Created Successfully!',
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
                      'Your budget has been created successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 24),
                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(
                            context,
                            true,
                          ); // Go back to budget page
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating budget: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
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
          child: const Icon(Icons.close, color: Colors.black87, size: 28),
        ),
        title: const Text(
          'New Budget',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            // Budget Amount Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _budgetAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: 'Budget Amount',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cycle Type Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButton<String>(
                value: _selectedCycleType,
                isExpanded: true,
                underline: Container(),
                items: _cycleTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCycleType = newValue;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Rollover Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rollover',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Switch(
                    value: _rolloverStatus,
                    onChanged: (bool value) {
                      setState(() {
                        _rolloverStatus = value;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Save Button
            GestureDetector(
              onTap: _isSaving ? null : _saveBudget,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade300,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.black87,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
