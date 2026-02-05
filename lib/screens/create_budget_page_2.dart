import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
      final budgetId = const Uuid().v4();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget created successfully')),
        );
        Navigator.pop(context);
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
