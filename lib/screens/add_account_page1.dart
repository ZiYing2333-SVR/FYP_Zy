import 'package:flutter/material.dart';
import 'add_account_page2.dart';
import 'add_account_ewallet.dart';
import 'add_account_page3.dart';

class AddAccountPage1 extends StatelessWidget {
  final String userId;

  const AddAccountPage1({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final accountTypes = [
      {'type': 'Debit Card', 'icon': Icons.credit_card},
      {'type': 'Credit Card', 'icon': Icons.credit_card},
      {'type': 'E-Wallet', 'icon': Icons.account_balance_wallet},
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
            // Account Type Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: accountTypes.length,
                itemBuilder: (context, index) {
                  final accountType = accountTypes[index];
                  return _buildAccountTypeCard(
                    context,
                    accountType['type'] as String,
                    accountType['icon'] as IconData,
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

  Widget _buildAccountTypeCard(
    BuildContext context,
    String accountType,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () {
        _handleAccountTypeSelection(context, accountType);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFA7E399),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.black87),
            const SizedBox(height: 16),
            Text(
              accountType,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAccountTypeSelection(BuildContext context, String accountType) {
    switch (accountType) {
      case 'E-Wallet':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AddAccountEWallet(accountType: accountType, userId: userId),
          ),
        );
        break;

      case 'Others':
        // Redirect to customization page (add_account_page3)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddAccountPage3(
              accountType: accountType,
              bankName: 'Custom Account',
              bankImage: null,
              userId: userId,
            ),
          ),
        );
        break;

      case 'Debit Card':
      case 'Credit Card':
        // Redirect to bank selection
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AddAccountPage2(accountType: accountType, userId: userId),
          ),
        );
        break;
    }
  }
}
