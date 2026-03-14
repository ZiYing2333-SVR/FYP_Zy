import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class ReceiptConfirmPage extends StatefulWidget {
  final ParsedReceipt receipt;

  const ReceiptConfirmPage({
    super.key,
    required this.receipt,
  });

  @override
  State<ReceiptConfirmPage> createState() => _ReceiptConfirmPageState();
}

class _ReceiptConfirmPageState extends State<ReceiptConfirmPage> {
  late TextEditingController amountController;
  late TextEditingController dateController;
  late List<TextEditingController> itemControllers;

  List<String> categories = [];
  String? selectedCategory;

  bool loadingCategories = true;

  @override
  void initState() {
    super.initState();

    amountController =
        TextEditingController(text: widget.receipt.amount);
    dateController =
        TextEditingController(text: widget.receipt.date ?? '');

    itemControllers = widget.receipt.items
        .map((e) => TextEditingController(text: e))
        .toList();

    selectedCategory = widget.receipt.categoryName;

    fetchCategories();
  }

  Future<void> fetchCategories() async {
    final res = await Supabase.instance.client
        .from('Category')
        .select('name');

    setState(() {
      categories = res.map<String>((e) => e['name'] as String).toList();
      loadingCategories = false;
    });
  }

  bool validateInputs() {
    if (amountController.text.trim().isEmpty) return false;
    if (itemControllers.isEmpty) return false;
    if (itemControllers.any((c) => c.text.trim().isEmpty)) return false;
    if (selectedCategory == null || selectedCategory!.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        title: const Text('Confirm Receipt'),
        backgroundColor: const Color(0xFFFEFFD3),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------- AMOUNT ----------
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- DATE ----------
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'Date (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- CATEGORY ----------
            loadingCategories
                ? const CircularProgressIndicator()
                : DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories
                  .map(
                    (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c),
                ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ---------- ITEMS ----------
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Items',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: itemControllers.isEmpty
                  ? const Center(
                child: Text(
                  'No items detected.\nPlease add items manually.',
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: itemControllers.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: itemControllers[i],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            itemControllers.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---------- ADD ITEM ----------
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              onPressed: () {
                setState(() {
                  itemControllers.add(TextEditingController());
                });
              },
            ),

            const SizedBox(height: 8),

            // ---------- CONFIRM ----------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA7E399),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Confirm & Save'),
                onPressed: () {
                  if (!validateInputs()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context, {
                    'amount': amountController.text.trim(),
                    'date': dateController.text.trim(),
                    'category': selectedCategory,
                    'items':
                    itemControllers.map((e) => e.text.trim()).toList(),
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
