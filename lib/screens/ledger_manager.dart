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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFA7E399),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Delete Ledger',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF39C12),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              'You are about to delete "$ledgerName".\n\nThis action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Delete Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteLedger(ledgerId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
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
                    final hasDescription =
                        ledger['description'] != null &&
                        ledger['description'].toString().isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditLedger(
                                    userId: widget.userId,
                                    ledgerId: ledger['ledgerId'],
                                    name: ledger['name'] ?? 'Unnamed Ledger',
                                    description: ledger['description'],
                                  ),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  _fetchLedgers();
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with Icon and Name
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFA7E399,
                                          ).withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.import_export,
                                          color: Color(0xFFA7E399),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ledger['name'] ??
                                                  'Unnamed Ledger',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (ledger['currencyId'] != null &&
                                                ledger['currencyId']
                                                    .toString()
                                                    .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4.0,
                                                ),
                                                child: Text(
                                                  'Currency: ${ledger['currencyId']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
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
                                                builder: (context) =>
                                                    EditLedger(
                                                      userId: widget.userId,
                                                      ledgerId:
                                                          ledger['ledgerId'],
                                                      name:
                                                          ledger['name'] ??
                                                          'Unnamed Ledger',
                                                      description:
                                                          ledger['description'],
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
                                              ledger['name'] ??
                                                  'Unnamed Ledger',
                                            );
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit,
                                                  size: 18,
                                                  color: Colors.blue,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  size: 18,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Description Section
                                  if (hasDescription) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F8E6),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFA7E399,
                                          ).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.description,
                                                size: 16,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Description',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            ledger['description'] ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[800],
                                              height: 1.4,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
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
