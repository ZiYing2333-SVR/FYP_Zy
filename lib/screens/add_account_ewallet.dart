import 'package:flutter/material.dart';
import '../services/ewallet_service.dart';
import '../utils/ewallet_icon_helper.dart';
import 'add_account_page3.dart';

// EWallet selection page for account creation - displays all available ewallets

class AddAccountEWallet extends StatefulWidget {
  final String accountType;
  final String userId;

  const AddAccountEWallet({
    super.key,
    required this.accountType,
    required this.userId,
  });

  @override
  State<AddAccountEWallet> createState() => _AddAccountEWalletState();
}

class _AddAccountEWalletState extends State<AddAccountEWallet> {
  late List<dynamic> allEWalletsWithSections;
  late List<dynamic> filteredEWalletsWithSections;
  bool isLoading = true;
  String? errorMessage;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadEWalletData();
  }

  Future<void> _loadEWalletData() async {
    try {
      print('📱 Loading e-wallets...');
      final ewallets = await EWalletService.getEWalletsWithSections();
      print('📊 Loaded ${ewallets.length} items');

      // Check if we have actual e-wallets (not just the customize option)
      final hasActualEWallets = ewallets.any(
        (item) => item is! Map || item['type'] != 'section',
      );

      setState(() {
        allEWalletsWithSections = ewallets;
        filteredEWalletsWithSections = ewallets;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      print('❌ Error loading ewallets: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: $e';
        allEWalletsWithSections = [];
        filteredEWalletsWithSections = [];
      });
    }
  }

  void _filterEWallets(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredEWalletsWithSections = allEWalletsWithSections;
      } else {
        final filtered = <dynamic>[];
        String? currentSection;

        for (var item in allEWalletsWithSections) {
          if (item is Map && item['type'] == 'section') {
            currentSection = item['title'];
          } else if (item is Map<String, dynamic>) {
            if (item['ewalletName'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                item['ewalletId'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                )) {
              // Add section header if it hasn't been added yet
              if (currentSection != null &&
                  (filtered.isEmpty ||
                      filtered.last is! Map ||
                      filtered.last['type'] != 'section' ||
                      filtered.last['title'] != currentSection)) {
                filtered.add({'type': 'section', 'title': currentSection});
              }
              filtered.add(item);
            }
          }
        }

        filteredEWalletsWithSections = filtered;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (errorMessage != null
                ? _buildErrorView()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        // Header
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.06,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.arrow_back, size: 28),
                            ),
                            const Text(
                              'Select E-Wallet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 28),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Search e-wallet...',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: _filterEWallets,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // EWallet List (No Filter Tabs)
                        Expanded(
                          child: filteredEWalletsWithSections.isEmpty
                              ? Center(
                                  child: Text(
                                    'No e-wallets found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      filteredEWalletsWithSections.length,
                                  itemBuilder: (context, index) {
                                    final item =
                                        filteredEWalletsWithSections[index];

                                    // Section header
                                    if (item is Map &&
                                        item['type'] == 'section') {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 16.0,
                                          bottom: 8.0,
                                        ),
                                        child: Text(
                                          item['title'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      );
                                    }

                                    // EWallet item
                                    final ewallet =
                                        item as Map<String, dynamic>;
                                    final displayName =
                                        EWalletService.cleanEWalletName(
                                          ewallet['ewalletName'],
                                        );
                                    final iconUrl = ewallet['isCustom'] == true
                                        ? ''
                                        : EWalletIconHelper.getEWalletIconUrl(
                                            ewallet['ewalletIcon'],
                                          );
                                    // Pass full URL for non-custom ewallets
                                    final ewalletIconForPage =
                                        ewallet['isCustom'] == true
                                        ? null
                                        : iconUrl;

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12.0,
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  AddAccountPage3(
                                                    accountType:
                                                        widget.accountType,
                                                    bankName: displayName,
                                                    bankImage:
                                                        ewalletIconForPage,
                                                    userId: widget.userId,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey[200]!,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // EWallet Icon
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child:
                                                    ewallet['isCustom'] == true
                                                    ? const Icon(
                                                        Icons.add,
                                                        size: 24,
                                                        color: Colors.grey,
                                                      )
                                                    : (iconUrl.isEmpty
                                                          ? const Icon(
                                                              Icons
                                                                  .account_balance_wallet,
                                                              size: 24,
                                                            )
                                                          : Image.network(
                                                              iconUrl,
                                                              fit: BoxFit
                                                                  .contain,
                                                              errorBuilder:
                                                                  (
                                                                    context,
                                                                    error,
                                                                    stackTrace,
                                                                  ) {
                                                                    return const Icon(
                                                                      Icons
                                                                          .account_balance_wallet,
                                                                      size: 24,
                                                                    );
                                                                  },
                                                            )),
                                              ),
                                              const SizedBox(width: 12),
                                              // EWallet Name
                                              Expanded(
                                                child: Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  )),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.06),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, size: 28),
              ),
              const Text(
                'Select E-Wallet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to Load E-Wallets',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      errorMessage ?? 'Unknown error',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Troubleshooting Steps:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Check that the EWallet table exists in Supabase\n'
                    '2. Verify the table has columns: ewalletId, ewalletName, ewalletIcon, ewalletType\n'
                    '3. Check Supabase RLS policies allow reading from the EWallet table\n'
                    '4. Ensure at least one e-wallet record exists in the table\n'
                    '5. Check Flutter console for detailed error logs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });
                      _loadEWalletData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA7E399),
                      foregroundColor: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
