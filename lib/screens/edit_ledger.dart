import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditLedger extends StatefulWidget {
  final String userId;
  final String ledgerId;
  final String name;
  final String? description;

  const EditLedger({
    super.key,
    required this.userId,
    required this.ledgerId,
    required this.name,
    this.description,
  });

  @override
  State<EditLedger> createState() => _EditLedgerState();
}

class _EditLedgerState extends State<EditLedger> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  //String? _selectedDefaultAccount;
  String _errorMessage = '';
  bool _isLoading = false;
 // List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.name;
    _descriptionController.text = widget.description ?? '';
    //_fetchAccounts();
  }

  // Future<void> _fetchAccounts() async {
  //   try {
  //     final response = await Supabase.instance.client
  //         .from('Account')
  //         .select()
  //         .eq('userId', widget.userId);

  //     setState(() {
  //       _accounts = List<Map<String, dynamic>>.from(response);
  //     });
  //   } catch (e) {
  //     print('Error fetching accounts: $e');
  //   }
  // }

  Future<void> _updateLedger() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    // Validation
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a ledger name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await Supabase.instance.client
          .from('Ledger')
          .update({'name': name, 'description': description})
          .eq('ledgerId', widget.ledgerId);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error updating ledger: $e');
      setState(() {
        _errorMessage = 'Error updating ledger. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Close button
              SizedBox(height: MediaQuery.of(context).size.height * 0.04),
              Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 28),
                ),
              ),
              const SizedBox(height: 20),
              // Edit Ledger Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFE5B4), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Center(
                      child: const Text(
                        'Edit Ledger',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Name Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFA7E399),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Uni Ledger',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBCBCBC),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Description Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFA7E399),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _descriptionController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Enter description...',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBCBCBC),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Error Message Display
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE74C3C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Cancel Button
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE5E5E5),
                                foregroundColor: Colors.black87,
                                disabledBackgroundColor: const Color(
                                  0xFFCCCCCC,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Save Button
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updateLedger,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFF866),
                                foregroundColor: Colors.black87,
                                disabledBackgroundColor: const Color(
                                  0xFFCCCCCC,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
