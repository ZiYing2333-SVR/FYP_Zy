# Implementation Guide - Update Savings Goal Screen

## Quick Integration Steps

### Step 1: Update `saving_goal_assistant_screen.dart`

Replace the `_analyzeSavingGoal()` method with income validation:

```dart
Future<void> _analyzeSavingGoal() async {
  if (!_formKey.currentState!.validate()) return;

  if (_selectedStartDate == null || _selectedEndDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select start and end dates')),
    );
    return;
  }

  if (_selectedEndDate!.isBefore(_selectedStartDate!)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('End date must be after start date')),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // NEW: Validate consistent income (3+ months of salary)
    final incomeValidation = await IntelligentSavingsGoalAssistant
        .validateConsistentIncome(widget.userId);

    if (!incomeValidation.hasConsistentIncome) {
      // User needs to record salary income first
      if (mounted) {
        _showIncomeRecordingDialog(incomeValidation);
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // NEW: Generate savings suggestion based on income
    final targetAmount = double.parse(_targetAmountController.text);
    final targetDate = _selectedEndDate!;

    final savingsSuggestion = await IntelligentSavingsGoalAssistant
        .generateSavingsSuggestion(
      userId: widget.userId,
      targetAmount: targetAmount,
      targetDate: targetDate,
    );

    if (!savingsSuggestion.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savingsSuggestion.feasibilityMessage,
            ),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });

    // Show savings suggestion summary before proceeding
    if (mounted) {
      _showSavingsSuggestionDialog(savingsSuggestion);
    }
  } catch (e) {
    print('Error analyzing saving goal: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }
}

/// Dialog to prompt user to record salary income
void _showIncomeRecordingDialog(IncomeValidationResult validation) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Record Monthly Salary'),
      content: Text(validation.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to Add Transaction with salary category auto-selected
            _navigateToAddIncome(validation.salaryCategoryId);
          },
          icon: const Icon(Icons.add),
          label: const Text('Record Salary'),
        ),
      ],
    ),
  );
}

/// Dialog showing savings suggestion summary
void _showSavingsSuggestionDialog(SavingsSuggestionResult suggestion) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Savings Goal Suggestion'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Suggested monthly savings (highlighted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suggested Monthly Savings',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${suggestion.suggestedMonthlySavings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'to reach RM ${suggestion.targetAmount.toStringAsFixed(2)} in ${suggestion.timelineMonths} months',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Analysis
            Text(
              'Analysis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.analysis,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            // Feasibility status
            Row(
              children: [
                Icon(
                  suggestion.isFeasible ? Icons.check_circle : Icons.warning,
                  color: suggestion.isFeasible ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    suggestion.feasibilityMessage,
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Adjust Goal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Proceed with planning using the suggestion
            _proceedWithGoal(suggestion);
          },
          child: const Text('Continue to Plan'),
        ),
      ],
    ),
  );
}

/// Navigate to Add Transaction screen with salary category auto-selected
void _navigateToAddIncome(String? salaryCategoryId) {
  // TODO: Implement based on your project structure
  // Example:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AddTransactionScreen(
        userId: widget.userId,
        initialCategoryId: salaryCategoryId,
        initialType: 'income',
        onTransactionAdded: () {
          // Refresh the page after income is recorded
          _initializePage();
        },
      ),
    ),
  );
}

/// Proceed with goal planning
void _proceedWithGoal(SavingsSuggestionResult suggestion) {
  // Navigate to plan screen with suggestion data
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SavingGoalPlanScreen(
        userId: widget.userId,
        suggestedMonthlySavings: suggestion.suggestedMonthlySavings,
        targetAmount: suggestion.targetAmount,
        targetDate: suggestion.targetDate,
        averageMonthlyIncome: suggestion.averageMonthlyIncome,
        isFeasible: suggestion.isFeasible,
      ),
    ),
  );
}
```

### Step 2: Update the Initial Build

Modify the build method to show income status:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Savings Goal Assistant'),
      elevation: 0,
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Income Status Card
          _buildIncomeStatusCard(),
          const SizedBox(height: 24),
          
          // Goal Input Fields (disabled if no consistent income)
          if (_hasConsistentIncome)
            _buildGoalInputFields()
          else
            _buildIncomePrompt(),
        ],
      ),
    ),
  );
}

/// Build card showing income status
Widget _buildIncomeStatusCard() {
  // Initialize income check on first build
  if (_incomeValidation == null) {
    _initializeIncomeCheck();
  }
  
  if (_isLoadingIncome) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  if (_incomeValidation == null) {
    return SizedBox.shrink();
  }
  
  return Card(
    color: _incomeValidation!.hasConsistentIncome
        ? Colors.green.shade50
        : Colors.orange.shade50,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _incomeValidation!.hasConsistentIncome
                    ? Icons.check_circle
                    : Icons.info,
                color: _incomeValidation!.hasConsistentIncome
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _incomeValidation!.message,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
          if (_incomeValidation!.hasConsistentIncome) ...[
            const SizedBox(height: 12),
            Text(
              'Your consistent monthly income: RM ${_incomeValidation!.averageMonthlyIncome.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            Text(
              'Based on ${_incomeValidation!.consistentMonthsCount} months of salary records',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Build goal input fields
Widget _buildGoalInputFields() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Savings Goal',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: 'Goal Name',
          hintText: 'e.g., Emergency Fund',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        validator: (value) =>
            value?.isEmpty ?? true ? 'Please enter goal name' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _targetAmountController,
        decoration: InputDecoration(
          labelText: 'Target Amount (RM)',
          hintText: '0.00',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        validator: (value) => value?.isEmpty ?? true
            ? 'Please enter target amount'
            : null,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _endDateController,
              decoration: InputDecoration(
                labelText: 'Target Date',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              readOnly: true,
              onTap: () => _selectDate(_endDateController, false),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please select date' : null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _selectDate(_endDateController, false),
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _analyzeSavingGoal,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Analyze Goal'),
        ),
      ),
    ],
  );
}

/// Build prompt to record income
Widget _buildIncomePrompt() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(
        Icons.money_off,
        size: 64,
        color: Colors.grey.shade300,
      ),
      const SizedBox(height: 16),
      Text(
        'Record Your Monthly Salary First',
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        _incomeValidation?.message ?? '',
        style: const TextStyle(fontSize: 13, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () {
          if (_incomeValidation != null) {
            _navigateToAddIncome(_incomeValidation!.salaryCategoryId);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Record Salary'),
      ),
    ],
  );
}
```

### Step 3: Add Instance Variables

Add these to the `_SavingGoalAssistantScreenState`:

```dart
// Income validation
IncomeValidationResult? _incomeValidation;
bool _isLoadingIncome = true;
bool _hasConsistentIncome = false;

// Savings suggestion
SavingsSuggestionResult? _savingsSuggestion;

void _initializeIncomeCheck() async {
  try {
    final validation = await IntelligentSavingsGoalAssistant
        .validateConsistentIncome(widget.userId);
    
    setState(() {
      _incomeValidation = validation;
      _hasConsistentIncome = validation.hasConsistentIncome;
      _isLoadingIncome = false;
    });
  } catch (e) {
    print('Error checking income: $e');
    setState(() {
      _isLoadingIncome = false;
    });
  }
}

@override
void initState() {
  super.initState();
  // ... existing code ...
  _initializeIncomeCheck();
}
```

### Step 4: Add Import Statement

At the top of the file:

```dart
import '../services/intelligent_savings_goal_assistant_service.dart';
```

---

## Key Implementation Points

1. **Always validate income first** - Call `validateConsistentIncome()` before `generateSavingsSuggestion()`

2. **Show meaningful messages** - Display `incomeValidation.message` to tell user what they need to do

3. **Auto-select salary category** - When redirecting to Add Transaction, pass `salaryCategoryId`

4. **Calculate monthly savings** - Use `suggestion.suggestedMonthlySavings` (already calculated as Goal ÷ Months)

5. **Show feasibility status** - Display icon (✓ or ⚠️) and `feasibilityMessage` to set expectations

6. **Handle errors gracefully** - Check `result.success` before using data

---

## Testing Scenarios

### Scenario 1: First-time user (no income records)
```
1. Open savings goal screen
2. See: "No salary income category found. Please record your monthly salary first."
3. Income status: ❌ Not set
4. Goal fields: Disabled
5. Click "Record Salary" → Navigate to Add Transaction (salary auto-selected)
```

### Scenario 2: User with 1-2 months of income
```
1. Open savings goal screen
2. See: "You need at least 3 months of consistent salary income"
3. Income status: ⚠️ Insufficient (1-2 months)
4. Goal fields: Disabled
5. Click "Record Salary" → Navigate to Add Transaction
```

### Scenario 3: User with 3+ months of income
```
1. Open savings goal screen
2. See: "Your consistent monthly income: RM 3,500" (average)
3. Income status: ✓ Set (3+ months)
4. Goal fields: Enabled
5. Enter:
   - Target: RM 5,000
   - Date: 12 months from now
6. Click "Analyze Goal"
7. Calculate: 5,000 ÷ 12 = RM 416.67/month
8. Show suggestion dialog with:
   - Monthly savings: RM 416.67
   - Feasible: ✓ Yes (compare to monthly net income)
   - Analysis: "Based on your income and expenses, this is achievable"
```

---

## Database Queries Reference

### Find or create salary category
```sql
SELECT * FROM "Category"
WHERE "userId" = $1
  AND type = 'income'
  AND name ILIKE '%salary%'
LIMIT 1;
```

### Get salary transactions (last 12 months)
```sql
SELECT * FROM "Transaction"
WHERE "categoryId" = $1
  AND date >= now() - interval '12 months'
ORDER BY date ASC;
```

### Get expense transactions (last 3 months)
```sql
SELECT * FROM "Transaction"
WHERE type = 'expense'
  AND date >= now() - interval '3 months';
```

