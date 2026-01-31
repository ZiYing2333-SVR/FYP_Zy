import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddLedger extends StatefulWidget {
  final String userId;

  const AddLedger({super.key, required this.userId});

  @override
  State<AddLedger> createState() => _AddLedgerState();
}

class _AddLedgerState extends State<AddLedger> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;

  Future<void> _createLedger() async {
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
      // Query the latest ledger for this user to get the next sequence number
      final response = await Supabase.instance.client
          .from('Ledger')
          .select('ledgerId')
          .eq('userId', widget.userId)
          .order('ledgerId', ascending: false)
          .limit(1);

      int nextSequence = 1;
      if (response.isNotEmpty) {
        final latestLedgerId = response[0]['ledgerId'] as String;
        // Extract the number from the ledger ID (e.g., "LEDuserid003" -> 003)
        final numberPart = latestLedgerId.substring(
          'LED${widget.userId}'.length,
        );
        try {
          nextSequence = int.parse(numberPart) + 1;
        } catch (e) {
          nextSequence = 1;
        }
      }

      // Format the sequence number with leading zeros (e.g., 001, 002, etc.)
      final formattedSequence = nextSequence.toString().padLeft(3, '0');
      final ledgerId = 'LED${widget.userId}$formattedSequence';

      await Supabase.instance.client.from('Ledger').insert({
        'ledgerId': ledgerId,
        'userId': widget.userId,
        'name': name,
        'description': description,
        'currencyId': null,
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error creating ledger: $e');
      setState(() {
        _errorMessage = 'Error creating ledger. Please try again.';
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
              // Add Ledger Card
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
                        'Add  ger',
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
                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createLedger,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF866),
                          foregroundColor: Colors.black87,
                          disabledBackgroundColor: const Color(0xFFCCCCCC),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : const Text('Create'),
                      ),
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
