import 'package:flutter/material.dart';
import 'add_account_page2.dart';

class AddAccountPage1 extends StatelessWidget {
  final String userId;

  const AddAccountPage1({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final accountTypes = [
      {'type': 'Debit Card', 'icon': Icons.credit_card},
      {'type': 'Credit Card', 'icon': Icons.credit_card},
      {'type': 'E-Wallet', 'icon': Icons.account_balance_wallet},
      {'type': 'Member Account', 'icon': Icons.person},
      {'type': 'Others', 'icon': Icons.more_horiz},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            // Header
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 28),
                ),
                const Text(
                  'Add Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 28), // For alignment
              ],
            ),
            const SizedBox(height: 40),
            // Account Type List
            Expanded(
              child: ListView.builder(
                itemCount: accountTypes.length,
                itemBuilder: (context, index) {
                  final accountType = accountTypes[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddAccountPage2(
                              accountType: accountType['type'] as String,
                              userId: userId,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA7E399),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              accountType['icon'] as IconData,
                              size: 28,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 20),
                            Text(
                              accountType['type'] as String,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
