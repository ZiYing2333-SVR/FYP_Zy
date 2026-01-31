import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../utils/bank_icon_helper.dart';
import 'add_account_page3.dart';

// Bank selection page for account creation - displays all available banks

class AddAccountPage2 extends StatefulWidget {
  final String accountType;
  final String userId;

  const AddAccountPage2({
    super.key,
    required this.accountType,
    required this.userId,
  });

  @override
  State<AddAccountPage2> createState() => _AddAccountPage2State();
}

class _AddAccountPage2State extends State<AddAccountPage2> {
  late List<dynamic> allBanksWithSections;
  late List<dynamic> filteredBanksWithSections;
  bool isLoading = true;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadBankData();
  }

  Future<void> _loadBankData() async {
    try {
      final banks = await BankService.getBanksWithSections();
      setState(() {
        allBanksWithSections = banks;
        filteredBanksWithSections = banks;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading banks: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterBanks(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredBanksWithSections = allBanksWithSections;
      } else {
        final filtered = <dynamic>[];
        String? currentSection;

        for (var item in allBanksWithSections) {
          if (item is Map && item['type'] == 'section') {
            currentSection = item['title'];
          } else if (item is Map<String, dynamic>) {
            if (item['bankName'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                item['bankId'].toString().toLowerCase().contains(
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

        filteredBanksWithSections = filtered;
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
          : Padding(
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
                        child: const Icon(Icons.arrow_back, size: 28),
                      ),
                      const Text(
                        'Select Bank',
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
                              hintText: 'Search bank...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onChanged: _filterBanks,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Bank List (No Filter Tabs)
                  Expanded(
                    child: filteredBanksWithSections.isEmpty
                        ? Center(
                            child: Text(
                              'No banks found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredBanksWithSections.length,
                            itemBuilder: (context, index) {
                              final item = filteredBanksWithSections[index];

                              // Section header
                              if (item is Map && item['type'] == 'section') {
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

                              // Bank item
                              final bank = item as Map<String, dynamic>;
                              final iconUrl = bank['isCustom'] == true
                                  ? ''
                                  : BankIconHelper.getBankIconUrl(
                                      bank['bankIcon'],
                                    );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddAccountPage3(
                                          accountType: widget.accountType,
                                          bankName: bank['bankName'],
                                          bankImage: bank['bankIcon'],
                                          userId: widget.userId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Bank Icon
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: bank['isCustom'] == true
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
                                                        fit: BoxFit.contain,
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
                                        // Bank Name
                                        Expanded(
                                          child: Text(
                                            bank['bankName'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
            ),
    );
  }
}
