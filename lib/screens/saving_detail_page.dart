import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavingDetailPage extends StatefulWidget {
  final String goalId;
  final String userId;

  const SavingDetailPage({
    super.key,
    required this.goalId,
    required this.userId,
  });

  @override
  State<SavingDetailPage> createState() => _SavingDetailPageState();
}

class _SavingDetailPageState extends State<SavingDetailPage> {
  Map<String, dynamic>? _savingGoal;
  Map<String, dynamic>? _destAccount;
  Map<String, dynamic>? _sourceAccount;
  Map<String, dynamic>? _linkedAccount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavingDetails();
  }

  Future<void> _fetchSavingDetails() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch saving goal details
      final goalResponse = await Supabase.instance.client
          .from('SavingGoal')
          .select()
          .eq('goalId', widget.goalId)
          .single();

      setState(() {
        _savingGoal = goalResponse;
      });

      // Fetch related account details
      if (_savingGoal != null) {
        await Future.wait([
          _fetchAccount(_savingGoal!['destAccountId']),
          _fetchAccount(_savingGoal!['sourceAcountId']),
          _fetchAccount(_savingGoal!['linkedAccountId']),
        ]);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching saving details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAccount(String accountId) async {
    try {
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('accountId', accountId)
          .single();

      setState(() {
        if (_savingGoal != null) {
          if (accountId == _savingGoal!['destAccountId']) {
            _destAccount = response;
          } else if (accountId == _savingGoal!['sourceAcountId']) {
            _sourceAccount = response;
          } else if (accountId == _savingGoal!['linkedAccountId']) {
            _linkedAccount = response;
          }
        }
      });
    } catch (e) {
      print('Error fetching account $accountId: $e');
    }
  }

  String _formatCurrency(dynamic value) {
    final amount = (value ?? 0).toDouble();
    return 'RM${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildAccountCard(String title, Map<String, dynamic>? account) {
    if (account == null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Account Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: account['iconImage'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        account['iconImage'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.account_balance_wallet,
                            color: Colors.grey.shade600,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.account_balance_wallet,
                      color: Colors.grey.shade600,
                    ),
            ),
            const SizedBox(width: 12),
            // Account Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account['accountName'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(account['balance']),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
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
      backgroundColor: const Color(0xFFFFFFFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saving Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savingGoal == null
          ? const Center(child: Text('Saving goal not found'))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Goal Overview Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _savingGoal!['name'] ?? 'Unnamed Goal',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Target',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(
                                      _savingGoal!['targetAmount'],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Saved',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(
                                      _destAccount?['balance'] ?? 0.0,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    (_savingGoal!['status'] ?? 'active')
                                        .toString()
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          (_savingGoal!['status'] == 'inactive'
                                                  ? Colors.grey
                                                  : Colors.blue)
                                              .shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  (_destAccount?['balance'] ?? 0) /
                                  (_savingGoal!['targetAmount'] ?? 1),
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final destBalance = _destAccount?['balance'] ?? 0;
                              final targetAmount =
                                  _savingGoal!['targetAmount'] ?? 1;
                              final progressPercentage =
                                  ((destBalance / targetAmount) * 100)
                                      .clamp(0, 100)
                                      .toStringAsFixed(1);

                              return Text(
                                '$progressPercentage% Complete',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Account Information Section
                    Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAccountCard('Destination Account', _destAccount),
                    _buildAccountCard('Source Account', _sourceAccount),
                    _buildAccountCard('Linked Account', _linkedAccount),
                    const SizedBox(height: 24),
                    // Goal Details Section
                    Text(
                      'Goal Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      'Goal Type',
                      _savingGoal!['type'] ?? 'N/A',
                    ),
                    _buildDetailCard(
                      'Start Date',
                      _formatDate(_savingGoal!['startDate']),
                    ),
                    _buildDetailCard(
                      'End Date',
                      _formatDate(_savingGoal!['endDate']),
                    ),
                    _buildDetailCard(
                      'Cycle Status',
                      _savingGoal!['cycleStatus'] == true
                          ? 'Active'
                          : 'Inactive',
                    ),
                    if (_savingGoal!['description'] != null &&
                        _savingGoal!['description'].toString().isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Description',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _savingGoal!['description'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
