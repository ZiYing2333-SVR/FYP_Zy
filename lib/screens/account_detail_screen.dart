import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'edit_account_page.dart';
import 'transaction_detail_screen.dart';
import 'transfer_detail_screen.dart';

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
  Map<String, dynamic> _currencies = {};

  @override
  void initState() {
    super.initState();
    _fetchCurrencies();
    _accountDetailsFuture = _fetchAccountDetails();
    _transactionsFuture = _fetchTransactions();
  }

  Future<void> _fetchCurrencies() async {
    try {
      final response = await Supabase.instance.client.from('Currency').select();

      final Map<String, dynamic> currencyMap = {};
      for (var currency in response) {
        currencyMap[currency['currencyId']] = currency;
      }

      setState(() {
        _currencies = currencyMap;
      });
    } catch (e) {
      print('Error fetching currencies: $e');
    }
  }

  String _getCurrencySymbol(String? currencyId) {
    if (currencyId == null || currencyId.isEmpty || currencyId == 'NULL') {
      return 'RM'; // Default fallback
    }
    final currency = _currencies[currencyId];
    if (currency != null && currency['symbol'] != null) {
      return currency['symbol'];
    }
    return currency?['code'] ?? 'RM';
  }

  String _formatCurrencyWithSymbol(double amount, String? currencyId) {
    final symbol = _getCurrencySymbol(currencyId);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  Future<Map<String, dynamic>> _fetchAccountDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('Account')
          .select()
          .eq('accountId', widget.accountId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching account details: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    try {
      // Fetch transactions for this account
      final transactionResponse = await Supabase.instance.client
          .from('Transaction')
          .select('''
            *,
            Category(name, icon),
            Account(accountName, iconImage)
          ''')
          .eq('accountId', widget.accountId)
          .order('date', ascending: false);

      // Fetch transfers where this account is either source or destination
      // Note: We fetch transfers without complex joins to avoid PostgreSQL table aliasing issues
      final transferResponse = await Supabase.instance.client
          .from('Transfer')
          .select('*')
          .or(
            'fromAccountId.eq.${widget.accountId},toAccountId.eq.${widget.accountId}',
          )
          .order('date', ascending: false);

      // Fetch all accounts for reference
      final accountsResponse = await Supabase.instance.client
          .from('Account')
          .select('accountId, accountName, iconImage');

      final accountsMap = {
        for (var account in accountsResponse) account['accountId']: account,
      };

      // Combine both lists
      List<Map<String, dynamic>> allRecords = [];

      // Add transactions
      allRecords.addAll(List<Map<String, dynamic>>.from(transactionResponse));

      // Add transfers with type indicator and enriched account data
      for (var transfer in transferResponse) {
        final enrichedTransfer = Map<String, dynamic>.from(transfer);
        enrichedTransfer['recordType'] =
            'transfer'; // To distinguish from transaction

        // Add account data for from and to accounts
        enrichedTransfer['Account!fromAccountId'] =
            accountsMap[transfer['fromAccountId']] ?? {};
        enrichedTransfer['Account!toAccountId'] =
            accountsMap[transfer['toAccountId']] ?? {};

        allRecords.add(enrichedTransfer);
      }

      // Sort all records by date (descending)
      allRecords.sort((a, b) {
        final dateA = DateTime.parse(a['date'] ?? '');
        final dateB = DateTime.parse(b['date'] ?? '');
        return dateB.compareTo(dateA);
      });

      return allRecords;
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
                // Account Header Card - Clickable to Edit
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditAccountPage(
                            account: accountData,
                            userId: widget.userId,
                            source: 'detail',
                          ),
                        ),
                      );
                      if (result == true) {
                        setState(() {
                          _accountDetailsFuture = _fetchAccountDetails();
                          _transactionsFuture = _fetchTransactions();
                        });
                      }
                    },
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
                                  fit: BoxFit.contain,
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
                                  _formatCurrencyWithSymbol(
                                    balance,
                                    accountData['currencyId'],
                                  ),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF52C77A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Edit Icon on the right
                          const Icon(
                            Icons.edit,
                            color: Color(0xFFF39C12),
                            size: 24,
                          ),
                        ],
                      ),
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
                                          'IN ${_getCurrencySymbol(accountData['currencyId'])}${dayIncome.toStringAsFixed(2)}',
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
                                          'OUT ${_getCurrencySymbol(accountData['currencyId'])}${dayExpense.toStringAsFixed(2)}',
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

                                final isTransfer =
                                    transaction['recordType'] == 'transfer';

                                // Handle both transaction and transfer records
                                String displayName = '';
                                String displayNote = '';
                                String displayIcon = 'shopping_bag';
                                dynamic accountLogo = '';
                                final amount = (transaction['amount'] ?? 0)
                                    .toDouble();

                                if (isTransfer) {
                                  // Transfer record
                                  final fromAccountData =
                                      transaction['Account!fromAccountId'] ??
                                      {};
                                  final toAccountData =
                                      transaction['Account!toAccountId'] ?? {};
                                  final isOutgoing =
                                      transaction['fromAccountId'] ==
                                      widget.accountId;

                                  final fromAccountName =
                                      fromAccountData['accountName'] ??
                                      'Unknown';
                                  final toAccountName =
                                      toAccountData['accountName'] ?? 'Unknown';

                                  displayName = isOutgoing
                                      ? 'Transfer to $toAccountName'
                                      : 'Transfer from $fromAccountName';
                                  displayNote = transaction['note'] ?? '';
                                  displayIcon =
                                      'send_icon'; // Use a transfer icon
                                  accountLogo = isOutgoing
                                      ? (toAccountData['iconImage'] ?? '')
                                      : (fromAccountData['iconImage'] ?? '');
                                } else {
                                  // Transaction record
                                  final categoryData =
                                      transaction['Category'] ?? {};
                                  final accountData =
                                      transaction['Account'] ?? {};

                                  displayName =
                                      categoryData['name'] ?? 'Category';
                                  displayIcon =
                                      categoryData['icon'] ?? 'shopping_bag';
                                  displayNote = transaction['note'] ?? '';
                                  accountLogo = accountData['iconImage'] ?? '';
                                }

                                final type = transaction['type'] ?? 'expense';
                                final isRefunded =
                                    transaction['refund'] == true;

                                return Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        if (isTransfer) {
                                          final transferId =
                                              transaction['transferId']
                                                  as String;
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  TransferDetailScreen(
                                                    transferId: transferId,
                                                    userId: widget.userId,
                                                  ),
                                            ),
                                          );
                                          if (result == true) {
                                            _fetchAccountDetails();
                                          }
                                        } else {
                                          final transactionId =
                                              transaction['transactionId']
                                                  as String;
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  TransactionDetailScreen(
                                                    transactionId:
                                                        transactionId,
                                                    userId: widget.userId,
                                                  ),
                                            ),
                                          );
                                          if (result == true) {
                                            _fetchAccountDetails();
                                          }
                                        }
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
                                              child: isTransfer
                                                  ? const Icon(
                                                      Icons.compare_arrows,
                                                      color: Colors.black,
                                                      size: 28,
                                                    )
                                                  : _buildCategoryImageWidget(
                                                      displayIcon,
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
                                                    displayName,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  if (displayNote.isNotEmpty)
                                                    Text(
                                                      displayNote,
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
                                                    Builder(
                                                      builder: (context) {
                                                        String amountDisplay;
                                                        Color amountColor;

                                                        if (isTransfer) {
                                                          final isOutgoing =
                                                              transaction['fromAccountId'] ==
                                                              widget.accountId;
                                                          amountDisplay =
                                                              '${isOutgoing ? '-' : '+'}RM${amount.toStringAsFixed(2)}';
                                                          amountColor =
                                                              isOutgoing
                                                              ? const Color(
                                                                  0xFFE74C3C,
                                                                )
                                                              : const Color(
                                                                  0xFF52C77A,
                                                                );
                                                        } else {
                                                          final accountData =
                                                              transaction['Account'] ??
                                                              {};
                                                          amountDisplay =
                                                              '${type == 'income' ? '+' : '-'}${_getCurrencySymbol(accountData['currencyId'])}${amount.toStringAsFixed(2)}';
                                                          amountColor =
                                                              type == 'income'
                                                              ? const Color(
                                                                  0xFF52C77A,
                                                                )
                                                              : const Color(
                                                                  0xFFE74C3C,
                                                                );
                                                        }

                                                        return Text(
                                                          amountDisplay,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: amountColor,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Account Icon in small circle
                                                    if (accountLogo
                                                            .toString()
                                                            .isNotEmpty &&
                                                        accountLogo != '')
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
                                                            accountLogo
                                                                .toString(),
                                                            fit: BoxFit.contain,
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
