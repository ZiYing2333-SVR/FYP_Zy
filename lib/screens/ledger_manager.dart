import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_ledger.dart';
import 'edit_ledger.dart';

class LedgerManager extends StatefulWidget {
  final String userId;

  const LedgerManager({super.key, required this.userId});

  @override
  State<LedgerManager> createState() => _LedgerManagerState();
}

class _LedgerManagerState extends State<LedgerManager> {
  List<Map<String, dynamic>> _ledgers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLedgers();
  }

  Future<void> _fetchLedgers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await Supabase.instance.client
          .from('Ledger')
          .select()
          .eq('userId', widget.userId);

      setState(() {
        _ledgers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching ledgers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLedger(String ledgerId) async {
    try {
      await Supabase.instance.client
          .from('Ledger')
          .delete()
          .eq('ledgerId', ledgerId);

      // Refresh the ledger list
      await _fetchLedgers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ledger deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting ledger: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting ledger'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(String ledgerId, String ledgerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        title: const Text('Delete Ledger'),
        content: Text('Are you sure you want to delete "$ledgerName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLedger(ledgerId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
              // Header
              SizedBox(height: MediaQuery.of(context).size.height * 0.04),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 28),
                  ),
                  const Text(
                    'Ledger Manager',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddLedger(userId: widget.userId),
                        ),
                      );

                      // Refresh ledgers if a new one was added
                      if (result == true) {
                        await _fetchLedgers();
                      }
                    },
                    child: const Icon(Icons.add, size: 28, color: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Ledger List
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                )
              else if (_ledgers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No ledgers yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first ledger',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ledgers.length,
                  itemBuilder: (context, index) {
                    final ledger = _ledgers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA7E399),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ledger['name'] ?? 'Unnamed Ledger',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (ledger['description'] != null &&
                                      ledger['description'].isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        ledger['description'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            PopupMenuButton(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditLedger(
                                        userId: widget.userId,
                                        ledgerId: ledger['ledgerId'],
                                        name:
                                            ledger['name'] ?? 'Unnamed Ledger',
                                        description: ledger['description'],
                                      ),
                                    ),
                                  ).then((result) {
                                    if (result == true) {
                                      _fetchLedgers();
                                    }
                                  });
                                } else if (value == 'delete') {
                                  _showDeleteConfirmation(
                                    ledger['ledgerId'],
                                    ledger['name'] ?? 'Unnamed Ledger',
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
