import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AccountDetailScreen extends StatefulWidget {
  final String accountId;
  final String userId;

  const AccountDetailScreen({
    Key? key,
    required this.accountId,
    required this.userId,
  }) : super(key: key);

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  late Future<Map<String, dynamic>> _accountDetailsFuture;
  late Future<List<Map<String, dynamic>>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _accountDetailsFuture = _fetchAccountDetails();
    _transactionsFuture = _fetchTransactions();
  }

  Future<Map<String, dynamic>> _fetchAccountDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('accountId', widget.accountId)
          .single();

      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error fetching account details: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    try {
      final response = await Supabase.instance.client
          .from('Transaction')
          .select('''
            *,
            Category(name, icon),
            Account(accountName, iconImage)
          ''')
          .eq('accountId', widget.accountId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching transactions: $e');
      rethrow;
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupTransactionsByDate(
    List<Map<String, dynamic>> transactions,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final transaction in transactions) {
      final date = transaction['date'];
      if (date != null) {
        final dateStr = DateFormat('EEE, MMM dd').format(DateTime.parse(date));
        grouped.putIfAbsent(dateStr, () => []).add(transaction);
      }
    }

    return grouped;
  }

  String _buildCategoryImage(dynamic categoryIcon) {
    if (categoryIcon == null || categoryIcon.isEmpty) {
      return 'shopping_bag';
    }
    if (categoryIcon.toString().startsWith('http') ||
        categoryIcon.toString().startsWith('/')) {
      return categoryIcon.toString();
    }
    return categoryIcon.toString();
  }

  Widget _buildCategoryImageWidget(dynamic categoryIcon) {
    final imageSource = _buildCategoryImage(categoryIcon);

    if (imageSource.startsWith('http') || imageSource.startsWith('/')) {
      return Image.network(
        imageSource,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.shopping_bag, size: 24, color: Colors.grey);
        },
      );
    }

    // Icon name mapping
    final iconMap = {
      'shopping_bag': Icons.shopping_bag,
      'restaurant': Icons.restaurant,
      'fuel': Icons.local_gas_station,
      'transport': Icons.directions_bus,
      'entertainment': Icons.movie,
      'health': Icons.local_hospital,
      'education': Icons.school,
      'utilities': Icons.water,
      'salary': Icons.attach_money,
      'bonus': Icons.card_giftcard,
      'investment': Icons.trending_up,
      'refund': Icons.undo,
    };

    return Icon(
      iconMap[imageSource] ?? Icons.category,
      size: 24,
      color: Colors.black87,
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Account Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _accountDetailsFuture,
        builder: (context, accountSnapshot) {
          if (accountSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (accountSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${accountSnapshot.error}'),
                ],
              ),
            );
          }

          if (!accountSnapshot.hasData) {
            return const Center(child: Text('No account data found'));
          }

          final accountData = accountSnapshot.data!;
          final accountName = accountData['accountName'] ?? 'Account';
          final balance = (accountData['balance'] ?? 0).toDouble();
          final accountIcon = accountData['iconImage'];

          return SingleChildScrollView(
            child: Column(
              children: [
                // Account Header Card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFE5B4),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Account Icon
                        if (accountIcon != null && accountIcon.isNotEmpty)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFE5B4),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                accountIcon,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.account_balance,
                                      size: 30,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        const SizedBox(width: 16),
                        // Account Name and Balance
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accountName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'RM${balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF52C77A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Transactions Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Transaction',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFBCBCBC),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Transactions List
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _transactionsFuture,
                  builder: (context, transactionsSnapshot) {
                    if (transactionsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (transactionsSnapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: ${transactionsSnapshot.error}'),
                      );
                    }

                    if (!transactionsSnapshot.hasData ||
                        transactionsSnapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No transactions found'),
                      );
                    }

                    final transactions = transactionsSnapshot.data!;
                    final groupedTransactions = _groupTransactionsByDate(
                      transactions,
                    );
                    final sortedDates = groupedTransactions.keys.toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        final dateKey = sortedDates[index];
                        final dayTransactions =
                            groupedTransactions[dateKey] ?? [];

                        // Calculate daily income and expense
                        double dayIncome = 0;
                        double dayExpense = 0;

                        for (final transaction in dayTransactions) {
                          final type = transaction['type'] ?? 'expense';
                          final amount = (transaction['amount'] ?? 0)
                              .toDouble();
                          if (type == 'income') {
                            dayIncome += amount;
                          } else {
                            dayExpense += amount;
                          }
                        }

                        return Column(
                          children: [
                            // Date Header with IN/OUT amounts
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateKey,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFBCBCBC),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (dayIncome > 0)
                                        Text(
                                          'IN RM${dayIncome.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF52C77A),
                                          ),
                                        ),
                                      if (dayIncome > 0 && dayExpense > 0)
                                        const SizedBox(width: 12),
                                      if (dayExpense > 0)
                                        Text(
                                          'OUT RM${dayExpense.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFE74C3C),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Transactions for this day
                            Column(
                              children: List.generate(dayTransactions.length, (
                                txIndex,
                              ) {
                                final transaction = dayTransactions[txIndex];
                                final isLastItem =
                                    txIndex == dayTransactions.length - 1;
                                final isLastDay =
                                    index == sortedDates.length - 1;

                                final categoryData =
                                    transaction['Category'] ?? {};
                                final categoryName =
                                    categoryData['name'] ?? 'Category';
                                final categoryIcon =
                                    categoryData['icon'] ?? 'shopping_bag';

                                final accountData =
                                    transaction['Account'] ?? {};
                                final accountLogo =
                                    accountData['iconImage'] ?? '';

                                final amount = (transaction['amount'] ?? 0)
                                    .toDouble();
                                final type = transaction['type'] ?? 'expense';
                                final note = transaction['note'] ?? '';
                                final isRefunded =
                                    transaction['refund'] == true;

                                return Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        // Transaction detail navigation can be added here
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFDD0),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFE5B4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Category Icon
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFC8A5D8),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: _buildCategoryImageWidget(
                                                categoryIcon,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Category Name and Note
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    categoryName,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  if (note.isNotEmpty)
                                                    Text(
                                                      note,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                          0xFFBCBCBC,
                                                        ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Right side: Amount, Account Icon, and Refund Badge
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Amount
                                                    Text(
                                                      '${type == 'income' ? '+' : '-'}RM${amount.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: type == 'income'
                                                            ? const Color(
                                                                0xFF52C77A,
                                                              )
                                                            : const Color(
                                                                0xFFE74C3C,
                                                              ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Account Icon in small circle
                                                    if (accountLogo.isNotEmpty)
                                                      Container(
                                                        width: 24,
                                                        height: 24,
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFFFFE5B4,
                                                            ),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: ClipOval(
                                                          child: Image.network(
                                                            accountLogo,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) {
                                                                  return Container(
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .grey[300],
                                                                      shape: BoxShape
                                                                          .circle,
                                                                    ),
                                                                    child: const Icon(
                                                                      Icons
                                                                          .account_balance,
                                                                      size: 12,
                                                                    ),
                                                                  );
                                                                },
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                // Refund Badge below amount and account icon
                                                if (isRefunded)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFFFE5B4,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'REFUNDED',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFFE74C3C,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Divider
                                    if (!isLastItem || !isLastDay)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Divider(
                                          color: const Color(0xFFFFE5B4),
                                          height: 1,
                                          thickness: 1,
                                        ),
                                      ),
                                  ],
                                );
                              }),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
