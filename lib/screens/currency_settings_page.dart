import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CurrencySettingsPage extends StatefulWidget {
  final String userId;

  const CurrencySettingsPage({super.key, required this.userId});

  @override
  State<CurrencySettingsPage> createState() => _CurrencySettingsPageState();
}

class _CurrencySettingsPageState extends State<CurrencySettingsPage> {
  late TextEditingController _searchController;
  String? _defaultCurrency;
  List<Map<String, dynamic>> _currencies = [];
  bool _isLoading = true;

  final List<Map<String, String>> currencyList = [
    {
      'currencyId': 'AFN',
      'name': 'Afghani',
      'symbol': 'AFN',
      'country': 'Afghanistan',
    },
    {'currencyId': 'ALL', 'name': 'Lek', 'symbol': 'ALL', 'country': 'Albania'},
    {
      'currencyId': 'DZD',
      'name': 'Algerian Dinar',
      'symbol': 'DZD',
      'country': 'Algeria',
    },
    {
      'currencyId': 'AOA',
      'name': 'Kwanza',
      'symbol': 'AOA',
      'country': 'Angola',
    },
    {
      'currencyId': 'ARS',
      'name': 'Argentine Peso',
      'symbol': 'ARS',
      'country': 'Argentina',
    },
    {
      'currencyId': 'AMD',
      'name': 'Armenian Dram',
      'symbol': 'AMD',
      'country': 'Armenia',
    },
    {
      'currencyId': 'AUD',
      'name': 'Australian Dollar',
      'symbol': 'AUD',
      'country': 'Australia',
    },
    {
      'currencyId': 'EUR',
      'name': 'Euro',
      'symbol': 'EUR',
      'country': 'Austria',
    },
    {
      'currencyId': 'AZN',
      'name': 'Azerbaijani Manat',
      'symbol': 'AZN',
      'country': 'Azerbaijan',
    },
    {
      'currencyId': 'BSD',
      'name': 'Bahamian Dollar',
      'symbol': 'BSD',
      'country': 'Bahamas',
    },
    {
      'currencyId': 'BHD',
      'name': 'Bahraini Dinar',
      'symbol': 'BHD',
      'country': 'Bahrain',
    },
    {
      'currencyId': 'BDT',
      'name': 'Taka',
      'symbol': 'BDT',
      'country': 'Bangladesh',
    },
    {
      'currencyId': 'BBD',
      'name': 'Barbados Dollar',
      'symbol': 'BBD',
      'country': 'Barbados',
    },
    {
      'currencyId': 'BYN',
      'name': 'Belarusian Ruble',
      'symbol': 'BYN',
      'country': 'Belarus',
    },
    {
      'currencyId': 'BZD',
      'name': 'Belize Dollar',
      'symbol': 'BZD',
      'country': 'Belize',
    },
    {
      'currencyId': 'XOF',
      'name': 'West African CFA Franc',
      'symbol': 'XOF',
      'country': 'Benin',
    },
    {
      'currencyId': 'BTN',
      'name': 'Ngultrum',
      'symbol': 'BTN',
      'country': 'Bhutan',
    },
    {
      'currencyId': 'BOB',
      'name': 'Boliviano',
      'symbol': 'BOB',
      'country': 'Bolivia',
    },
    {
      'currencyId': 'BAM',
      'name': 'Convertible Mark',
      'symbol': 'BAM',
      'country': 'Bosnia and Herzegovina',
    },
    {
      'currencyId': 'BWP',
      'name': 'Pula',
      'symbol': 'BWP',
      'country': 'Botswana',
    },
    {
      'currencyId': 'BRL',
      'name': 'Brazilian Real',
      'symbol': 'BRL',
      'country': 'Brazil',
    },
    {
      'currencyId': 'BND',
      'name': 'Brunei Dollar',
      'symbol': 'BND',
      'country': 'Brunei',
    },
    {
      'currencyId': 'BGN',
      'name': 'Bulgarian Lev',
      'symbol': 'BGN',
      'country': 'Bulgaria',
    },
    {
      'currencyId': 'BIF',
      'name': 'Burundian Franc',
      'symbol': 'BIF',
      'country': 'Burundi',
    },
    {
      'currencyId': 'KHR',
      'name': 'Riel',
      'symbol': 'KHR',
      'country': 'Cambodia',
    },
    {
      'currencyId': 'XAF',
      'name': 'Central African CFA Franc',
      'symbol': 'XAF',
      'country': 'Cameroon',
    },
    {
      'currencyId': 'CAD',
      'name': 'Canadian Dollar',
      'symbol': 'CAD',
      'country': 'Canada',
    },
    {
      'currencyId': 'CVE',
      'name': 'Cabo Verde Escudo',
      'symbol': 'CVE',
      'country': 'Cape Verde',
    },
    {
      'currencyId': 'CLP',
      'name': 'Chilean Peso',
      'symbol': 'CLP',
      'country': 'Chile',
    },
    {
      'currencyId': 'CNY',
      'name': 'Yuan Renminbi',
      'symbol': 'CNY',
      'country': 'China',
    },
    {
      'currencyId': 'COP',
      'name': 'Colombian Peso',
      'symbol': 'COP',
      'country': 'Colombia',
    },
    {
      'currencyId': 'KMF',
      'name': 'Comorian Franc',
      'symbol': 'KMF',
      'country': 'Comoros',
    },
    {
      'currencyId': 'CDF',
      'name': 'Congolese Franc',
      'symbol': 'CDF',
      'country': 'Congo (DRC)',
    },
    {
      'currencyId': 'CRC',
      'name': 'Costa Rican Colon',
      'symbol': 'CRC',
      'country': 'Costa Rica',
    },
    {
      'currencyId': 'CUP',
      'name': 'Cuban Peso',
      'symbol': 'CUP',
      'country': 'Cuba',
    },
    {
      'currencyId': 'CZK',
      'name': 'Czech Koruna',
      'symbol': 'CZK',
      'country': 'Czech Republic',
    },
    {
      'currencyId': 'DKK',
      'name': 'Danish Krone',
      'symbol': 'DKK',
      'country': 'Denmark',
    },
    {
      'currencyId': 'DJF',
      'name': 'Djiboutian Franc',
      'symbol': 'DJF',
      'country': 'Djibouti',
    },
    {
      'currencyId': 'DOP',
      'name': 'Dominican Peso',
      'symbol': 'DOP',
      'country': 'Dominican Republic',
    },
    {
      'currencyId': 'USD',
      'name': 'US Dollar',
      'symbol': 'USD',
      'country': 'United States',
    },
    {
      'currencyId': 'EGP',
      'name': 'Egyptian Pound',
      'symbol': 'EGP',
      'country': 'Egypt',
    },
    {
      'currencyId': 'ETB',
      'name': 'Ethiopian Birr',
      'symbol': 'ETB',
      'country': 'Ethiopia',
    },
    {
      'currencyId': 'FJD',
      'name': 'Fiji Dollar',
      'symbol': 'FJD',
      'country': 'Fiji',
    },
    {
      'currencyId': 'GEL',
      'name': 'Lari',
      'symbol': 'GEL',
      'country': 'Georgia',
    },
    {
      'currencyId': 'GHS',
      'name': 'Ghana Cedi',
      'symbol': 'GHS',
      'country': 'Ghana',
    },
    {
      'currencyId': 'GTQ',
      'name': 'Quetzal',
      'symbol': 'GTQ',
      'country': 'Guatemala',
    },
    {
      'currencyId': 'GNF',
      'name': 'Guinean Franc',
      'symbol': 'GNF',
      'country': 'Guinea',
    },
    {
      'currencyId': 'GYD',
      'name': 'Guyana Dollar',
      'symbol': 'GYD',
      'country': 'Guyana',
    },
    {
      'currencyId': 'HTG',
      'name': 'Gourde',
      'symbol': 'HTG',
      'country': 'Haiti',
    },
    {
      'currencyId': 'HNL',
      'name': 'Lempira',
      'symbol': 'HNL',
      'country': 'Honduras',
    },
    {
      'currencyId': 'HKD',
      'name': 'Hong Kong Dollar',
      'symbol': 'HKD',
      'country': 'Hong Kong',
    },
    {
      'currencyId': 'HUF',
      'name': 'Forint',
      'symbol': 'HUF',
      'country': 'Hungary',
    },
    {
      'currencyId': 'ISK',
      'name': 'Iceland Krona',
      'symbol': 'ISK',
      'country': 'Iceland',
    },
    {
      'currencyId': 'INR',
      'name': 'Indian Rupee',
      'symbol': 'INR',
      'country': 'India',
    },
    {
      'currencyId': 'IDR',
      'name': 'Rupiah',
      'symbol': 'IDR',
      'country': 'Indonesia',
    },
    {
      'currencyId': 'IRR',
      'name': 'Iranian Rial',
      'symbol': 'IRR',
      'country': 'Iran',
    },
    {
      'currencyId': 'IQD',
      'name': 'Iraqi Dinar',
      'symbol': 'IQD',
      'country': 'Iraq',
    },
    {
      'currencyId': 'ILS',
      'name': 'New Israeli Shekel',
      'symbol': 'ILS',
      'country': 'Israel',
    },
    {
      'currencyId': 'JMD',
      'name': 'Jamaican Dollar',
      'symbol': 'JMD',
      'country': 'Jamaica',
    },
    {'currencyId': 'JPY', 'name': 'Yen', 'symbol': 'JPY', 'country': 'Japan'},
    {
      'currencyId': 'JOD',
      'name': 'Jordanian Dinar',
      'symbol': 'JOD',
      'country': 'Jordan',
    },
    {
      'currencyId': 'KZT',
      'name': 'Tenge',
      'symbol': 'KZT',
      'country': 'Kazakhstan',
    },
    {
      'currencyId': 'KES',
      'name': 'Kenyan Shilling',
      'symbol': 'KES',
      'country': 'Kenya',
    },
    {
      'currencyId': 'KWD',
      'name': 'Kuwaiti Dinar',
      'symbol': 'KWD',
      'country': 'Kuwait',
    },
    {
      'currencyId': 'LAK',
      'name': 'Lao Kip',
      'symbol': 'LAK',
      'country': 'Laos',
    },
    {
      'currencyId': 'LBP',
      'name': 'Lebanese Pound',
      'symbol': 'LBP',
      'country': 'Lebanon',
    },
    {
      'currencyId': 'LSL',
      'name': 'Loti',
      'symbol': 'LSL',
      'country': 'Lesotho',
    },
    {
      'currencyId': 'LRD',
      'name': 'Liberian Dollar',
      'symbol': 'LRD',
      'country': 'Liberia',
    },
    {
      'currencyId': 'LYD',
      'name': 'Libyan Dinar',
      'symbol': 'LYD',
      'country': 'Libya',
    },
    {
      'currencyId': 'MYR',
      'name': 'Malaysian Ringgit',
      'symbol': 'MYR',
      'country': 'Malaysia',
    },
    {
      'currencyId': 'MVR',
      'name': 'Rufiyaa',
      'symbol': 'MVR',
      'country': 'Maldives',
    },
    {
      'currencyId': 'MXN',
      'name': 'Mexican Peso',
      'symbol': 'MXN',
      'country': 'Mexico',
    },
    {
      'currencyId': 'MDL',
      'name': 'Moldovan Leu',
      'symbol': 'MDL',
      'country': 'Moldova',
    },
    {
      'currencyId': 'MNT',
      'name': 'Tugrik',
      'symbol': 'MNT',
      'country': 'Mongolia',
    },
    {
      'currencyId': 'MAD',
      'name': 'Moroccan Dirham',
      'symbol': 'MAD',
      'country': 'Morocco',
    },
    {
      'currencyId': 'MMK',
      'name': 'Kyat',
      'symbol': 'MMK',
      'country': 'Myanmar',
    },
    {
      'currencyId': 'NAD',
      'name': 'Namibian Dollar',
      'symbol': 'NAD',
      'country': 'Namibia',
    },
    {
      'currencyId': 'NPR',
      'name': 'Nepalese Rupee',
      'symbol': 'NPR',
      'country': 'Nepal',
    },
    {
      'currencyId': 'NZD',
      'name': 'New Zealand Dollar',
      'symbol': 'NZD',
      'country': 'New Zealand',
    },
    {
      'currencyId': 'NGN',
      'name': 'Naira',
      'symbol': 'NGN',
      'country': 'Nigeria',
    },
    {
      'currencyId': 'KPW',
      'name': 'North Korean Won',
      'symbol': 'KPW',
      'country': 'North Korea',
    },
    {
      'currencyId': 'NOK',
      'name': 'Norwegian Krone',
      'symbol': 'NOK',
      'country': 'Norway',
    },
    {
      'currencyId': 'OMR',
      'name': 'Omani Rial',
      'symbol': 'OMR',
      'country': 'Oman',
    },
    {
      'currencyId': 'PKR',
      'name': 'Pakistan Rupee',
      'symbol': 'PKR',
      'country': 'Pakistan',
    },
    {
      'currencyId': 'PAB',
      'name': 'Balboa',
      'symbol': 'PAB',
      'country': 'Panama',
    },
    {
      'currencyId': 'PYG',
      'name': 'Guarani',
      'symbol': 'PYG',
      'country': 'Paraguay',
    },
    {'currencyId': 'PEN', 'name': 'Sol', 'symbol': 'PEN', 'country': 'Peru'},
    {
      'currencyId': 'PHP',
      'name': 'Philippine Peso',
      'symbol': 'PHP',
      'country': 'Philippines',
    },
    {
      'currencyId': 'PLN',
      'name': 'Zloty',
      'symbol': 'PLN',
      'country': 'Poland',
    },
    {
      'currencyId': 'QAR',
      'name': 'Qatari Riyal',
      'symbol': 'QAR',
      'country': 'Qatar',
    },
    {
      'currencyId': 'RON',
      'name': 'Romanian Leu',
      'symbol': 'RON',
      'country': 'Romania',
    },
    {
      'currencyId': 'RUB',
      'name': 'Russian Ruble',
      'symbol': 'RUB',
      'country': 'Russia',
    },
    {
      'currencyId': 'RWF',
      'name': 'Rwandan Franc',
      'symbol': 'RWF',
      'country': 'Rwanda',
    },
    {
      'currencyId': 'SAR',
      'name': 'Saudi Riyal',
      'symbol': 'SAR',
      'country': 'Saudi Arabia',
    },
    {
      'currencyId': 'RSD',
      'name': 'Serbian Dinar',
      'symbol': 'RSD',
      'country': 'Serbia',
    },
    {
      'currencyId': 'SGD',
      'name': 'Singapore Dollar',
      'symbol': 'SGD',
      'country': 'Singapore',
    },
    {
      'currencyId': 'ZAR',
      'name': 'Rand',
      'symbol': 'ZAR',
      'country': 'South Africa',
    },
    {
      'currencyId': 'KRW',
      'name': 'Won',
      'symbol': 'KRW',
      'country': 'South Korea',
    },
    {
      'currencyId': 'LKR',
      'name': 'Sri Lankan Rupee',
      'symbol': 'LKR',
      'country': 'Sri Lanka',
    },
    {
      'currencyId': 'SDG',
      'name': 'Sudanese Pound',
      'symbol': 'SDG',
      'country': 'Sudan',
    },
    {
      'currencyId': 'SEK',
      'name': 'Swedish Krona',
      'symbol': 'SEK',
      'country': 'Sweden',
    },
    {
      'currencyId': 'CHF',
      'name': 'Swiss Franc',
      'symbol': 'CHF',
      'country': 'Switzerland',
    },
    {
      'currencyId': 'SYP',
      'name': 'Syrian Pound',
      'symbol': 'SYP',
      'country': 'Syria',
    },
    {
      'currencyId': 'TWD',
      'name': 'New Taiwan Dollar',
      'symbol': 'TWD',
      'country': 'Taiwan',
    },
    {
      'currencyId': 'TZS',
      'name': 'Tanzanian Shilling',
      'symbol': 'TZS',
      'country': 'Tanzania',
    },
    {
      'currencyId': 'THB',
      'name': 'Baht',
      'symbol': 'THB',
      'country': 'Thailand',
    },
    {
      'currencyId': 'TND',
      'name': 'Tunisian Dinar',
      'symbol': 'TND',
      'country': 'Tunisia',
    },
    {
      'currencyId': 'TRY',
      'name': 'Turkish Lira',
      'symbol': 'TRY',
      'country': 'Turkey',
    },
    {
      'currencyId': 'UGX',
      'name': 'Ugandan Shilling',
      'symbol': 'UGX',
      'country': 'Uganda',
    },
    {
      'currencyId': 'UAH',
      'name': 'Hryvnia',
      'symbol': 'UAH',
      'country': 'Ukraine',
    },
    {
      'currencyId': 'AED',
      'name': 'UAE Dirham',
      'symbol': 'AED',
      'country': 'United Arab Emirates',
    },
    {
      'currencyId': 'GBP',
      'name': 'Pound Sterling',
      'symbol': 'GBP',
      'country': 'United Kingdom',
    },
    {
      'currencyId': 'UYU',
      'name': 'Uruguayan Peso',
      'symbol': 'UYU',
      'country': 'Uruguay',
    },
    {
      'currencyId': 'UZS',
      'name': 'Uzbek Som',
      'symbol': 'UZS',
      'country': 'Uzbekistan',
    },
    {
      'currencyId': 'VES',
      'name': 'Bolivar Soberano',
      'symbol': 'VES',
      'country': 'Venezuela',
    },
    {
      'currencyId': 'VND',
      'name': 'Dong',
      'symbol': 'VND',
      'country': 'Vietnam',
    },
    {
      'currencyId': 'YER',
      'name': 'Yemeni Rial',
      'symbol': 'YER',
      'country': 'Yemen',
    },
    {
      'currencyId': 'ZMW',
      'name': 'Zambian Kwacha',
      'symbol': 'ZMW',
      'country': 'Zambia',
    },
    {
      'currencyId': 'ZWL',
      'name': 'Zimbabwe Dollar',
      'symbol': 'ZWL',
      'country': 'Zimbabwe',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      // Initialize currencies in Supabase if not already done
      await _seedCurrencies();

      // Fetch user's default currency
      await _fetchUserDefaultCurrency();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading currencies: $e')));
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _seedCurrencies() async {
    try {
      // Check if currencies already exist
      final existingCurrencies = await Supabase.instance.client
          .from('Currency')
          .select()
          .limit(1);

      if (existingCurrencies.isEmpty) {
        // Insert all currencies
        final currenciesToInsert = currencyList
            .map(
              (c) => {
                'currencyId': c['currencyId'],
                'name': c['name'],
                'symbol': c['symbol'],
                'iconImage': null,
              },
            )
            .toList();

        await Supabase.instance.client
            .from('Currency')
            .insert(currenciesToInsert);
      }

      // Load currencies for display
      final currencies = await Supabase.instance.client
          .from('Currency')
          .select();
      setState(() {
        _currencies = List<Map<String, dynamic>>.from(currencies);
      });
    } catch (e) {
      print('Error seeding currencies: $e');
      // Use local list as fallback
      setState(() {
        _currencies = currencyList.map((c) {
          return {
            'currencyId': c['currencyId'],
            'name': c['name'],
            'symbol': c['symbol'],
            'iconImage': null,
          };
        }).toList();
      });
    }
  }

  Future<void> _fetchUserDefaultCurrency() async {
    try {
      final response = await Supabase.instance.client
          .from('UserCurrency')
          .select()
          .eq('userId', widget.userId);

      if (response.isNotEmpty) {
        setState(() {
          _defaultCurrency = response[0]['currencyId'];
        });
      } else {
        // Default to MYR if not set
        setState(() {
          _defaultCurrency = 'CUR0001';
        });
      }
    } catch (e) {
      print('Error fetching user currency: $e');
      // Default to MYR
      setState(() {
        _defaultCurrency = 'CUR0001';
      });
    }
  }

  Future<void> _updateUserCurrency(String currencyId) async {
    try {
      // Try to update existing record
      await Supabase.instance.client
          .from('UserCurrency')
          .update({'currencyId': currencyId})
          .eq('userId', widget.userId);

      setState(() {
        _defaultCurrency = currencyId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Currency updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Update error: $e');
      // If update fails, try insert (first time setup)
      try {
        await Supabase.instance.client.from('UserCurrency').insert({
          'userId': widget.userId,
          'currencyId': currencyId,
        });

        setState(() {
          _defaultCurrency = currencyId;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Currency set successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (insertError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating currency: $insertError')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFEFFD3),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      body: SingleChildScrollView(
        child: Padding(
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
                    'Currency Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
              const SizedBox(height: 24),

              // Default Currency Section
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFA7E399),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Default Currency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _defaultCurrency ?? 'MYR',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                          hintText: 'Search currency',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Currency List
              _buildCurrencyList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyList() {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredCurrencies = _currencies
        .where(
          (currency) =>
              (currency['name'] as String).toLowerCase().contains(
                searchQuery,
              ) ||
              (currency['symbol'] as String).toLowerCase().contains(
                searchQuery,
              ),
        )
        .toList();

    if (filteredCurrencies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'No currencies found',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredCurrencies.length,
      itemBuilder: (context, index) {
        final currency = filteredCurrencies[index];
        final isSelected = currency['currencyId'] == _defaultCurrency;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              _updateUserCurrency(currency['currencyId']);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF90EE90)
                    : const Color(0xFFA7E399),
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: Colors.green, width: 2)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency['name'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currency['symbol'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
