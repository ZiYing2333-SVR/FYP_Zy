import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class EWalletService {
  static const String tableName = 'EWallet';
  static const String bucketName = 'images';
  static const String ewalletIconFolder = 'ewallet';

  /// Fetch all ewallets from Supabase database
  static Future<List<Map<String, dynamic>>> getAllEWallets() async {
    try {
      print('📚 Fetching ewallets from table: $tableName');
      final response = await Supabase.instance.client
          .from(tableName)
          .select()
          .order('ewalletName');

      print('✅ EWallets fetched: ${response.length} records');
      if (response.isEmpty) {
        print('⚠️  Warning: EWallet table is empty!');
      } else {
        print('📋 Sample ewallet: ${response.first}');
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching ewallets: $e');
      print('🔍 Make sure:');
      print('   1. Supabase is initialized');
      print('   2. Table name is "EWallet" (case-sensitive)');
      print('   3. EWallet table has data');
      return [];
    }
  }

  /// Get ewallet icon URL - handles both full URLs and filenames
  static String getEWalletIconUrl(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return '';
    }

    // If it's already a full URL, return as is
    if (iconPath.startsWith('http')) {
      return iconPath;
    }

    // Otherwise, construct URL from filename
    const baseUrl =
        'https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3';
    return '$baseUrl/$bucketName/$ewalletIconFolder/$iconPath';
  }

  /// Get ewallet type from database ewalletType field
  static String _getEWalletTypeFromDatabase(String? ewalletType) {
    if (ewalletType == null || ewalletType.isEmpty) return 'Local';
    // Capitalize first letter (database has lowercase: 'local', 'foreign')
    return ewalletType[0].toUpperCase() + ewalletType.substring(1);
  }

  /// Clean ewallet name - remove "Ewallet" word from display
  static String cleanEWalletName(String name) {
    // Remove "ewallet" (case-insensitive) from the name
    return name
        .replaceAll(RegExp(r'\s*ewallet\s*', caseSensitive: false), '')
        .trim();
  }

  /// Group ewallets by type (Local, Foreign) and sort alphabetically within each group
  static Future<Map<String, List<Map<String, dynamic>>>>
  getEWalletsByType() async {
    try {
      final ewallets = await getAllEWallets();
      final Map<String, List<Map<String, dynamic>>> grouped = {
        'Local': [],
        'Foreign': [],
      };

      for (var ewallet in ewallets) {
        final type = _getEWalletTypeFromDatabase(ewallet['ewalletType']);
        print(
          '💳 EWallet: ${ewallet['ewalletName']} (${ewallet['ewalletId']}) → Type: $type',
        );
        if (grouped.containsKey(type)) {
          grouped[type]!.add(ewallet);
        }
      }

      // Sort each group alphabetically by ewallet name
      grouped.forEach((key, ewallets) {
        ewallets.sort(
          (a, b) => (a['ewalletName'] as String).compareTo(
            b['ewalletName'] as String,
          ),
        );
        print('📊 $key EWallets: ${ewallets.length}');
      });

      return grouped;
    } catch (e) {
      print('Error grouping ewallets: $e');
      return {'Local': [], 'Foreign': []};
    }
  }

  /// Get all ewallets sorted and grouped by type with section headers
  static Future<List<dynamic>> getEWalletsWithSections() async {
    try {
      print('🔄 Starting getEWalletsWithSections...');
      final grouped = await getEWalletsByType();
      final List<dynamic> result = [];

      final typeOrder = ['Local', 'Foreign'];
      int totalEWallets = 0;

      for (String type in typeOrder) {
        if (grouped[type]!.isNotEmpty) {
          result.add({'type': 'section', 'title': type});
          result.addAll(grouped[type]!);
          totalEWallets += grouped[type]!.length;
        }
      }

      print('✅ Found $totalEWallets e-wallets');

      // Add Customize section
      result.add({'type': 'section', 'title': 'Customize'});
      result.add({
        'ewalletId': 'CUSTOM',
        'ewalletName': 'Add Custom EWallet',
        'ewalletIcon': null,
        'ewalletType': 'Customize',
        'isCustom': true,
      });

      print('📊 Total items with sections: ${result.length}');
      return result;
    } catch (e) {
      print('❌ Error getting ewallets with sections: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Get demo ewallets for testing
  static Future<List<dynamic>> getDemoEWalletsWithSections() async {
    final List<dynamic> result = [
      {'type': 'section', 'title': 'Local'},
      {
        'ewalletId': 'demo_1',
        'ewalletName': 'GCash',
        'ewalletIcon': 'gcash.png',
        'ewalletType': 'Local',
        'isCustom': false,
      },
      {
        'ewalletId': 'demo_2',
        'ewalletName': 'Paymaya',
        'ewalletIcon': 'paymaya.png',
        'ewalletType': 'Local',
        'isCustom': false,
      },
      {'type': 'section', 'title': 'Foreign'},
      {
        'ewalletId': 'demo_3',
        'ewalletName': 'PayPal',
        'ewalletIcon': 'paypal.png',
        'ewalletType': 'Foreign',
        'isCustom': false,
      },
      {'type': 'section', 'title': 'Customize'},
      {
        'ewalletId': 'CUSTOM',
        'ewalletName': 'Add Custom EWallet',
        'ewalletIcon': null,
        'ewalletType': 'Customize',
        'isCustom': true,
      },
    ];
    return result;
  }

  /// Insert ewallet data (useful for initial setup)
  static Future<void> insertEWallets(
    List<Map<String, dynamic>> ewallets,
  ) async {
    try {
      await Supabase.instance.client.from(tableName).insert(ewallets);
      print('EWallets inserted successfully');
    } catch (e) {
      print('Error inserting ewallets: $e');
    }
  }

  /// Upload ewallet icon to storage
  static Future<String?> uploadEWalletIcon(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      await Supabase.instance.client.storage
          .from(bucketName)
          .uploadBinary(
            '$ewalletIconFolder/$fileName',
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return fileName;
    } catch (e) {
      print('Error uploading ewallet icon: $e');
      return null;
    }
  }

  /// Delete ewallet icon from storage
  static Future<void> deleteEWalletIcon(String fileName) async {
    try {
      await Supabase.instance.client.storage.from(bucketName).remove([
        '$ewalletIconFolder/$fileName',
      ]);
      print('EWallet icon deleted successfully');
    } catch (e) {
      print('Error deleting ewallet icon: $e');
    }
  }
}
