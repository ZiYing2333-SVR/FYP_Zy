import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class BankService {
  static const String tableName = 'Bank';
  static const String bucketName = 'images';
  static const String bankIconFolder = 'bank_icon';

  /// Fetch all banks from Supabase database
  static Future<List<Map<String, dynamic>>> getAllBanks() async {
    try {
      print('📚 Fetching banks from table: $tableName');
      final response = await Supabase.instance.client
          .from(tableName)
          .select()
          .order('bankName');

      print('✅ Banks fetched: ${response.length} records');
      if (response.isEmpty) {
        print('⚠️  Warning: Bank table is empty!');
      } else {
        print('📋 Sample bank: ${response.first}');
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching banks: $e');
      print('🔍 Make sure:');
      print('   1. Supabase is initialized');
      print('   2. Table name is "Bank" (case-sensitive)');
      print('   3. Bank table has data');
      return [];
    }
  }

  /// Get bank icon URL - handles both full URLs and filenames
  static String getBankIconUrl(String? iconPath) {
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
    return '$baseUrl/$bucketName/$bankIconFolder/$iconPath';
  }

  /// Get bank type from database bankType field
  static String _getBankTypeFromDatabase(String? bankType) {
    if (bankType == null || bankType.isEmpty) return 'Local';
    return bankType;
  }

  /// Group banks by type (Local, Islamic, Foreign) and sort alphabetically within each group
  static Future<Map<String, List<Map<String, dynamic>>>>
  getBanksByType() async {
    try {
      final banks = await getAllBanks();
      final Map<String, List<Map<String, dynamic>>> grouped = {
        'Local': [],
        'Islamic': [],
        'Foreign': [],
      };

      for (var bank in banks) {
        final type = _getBankTypeFromDatabase(bank['bankType']);
        print('🏦 Bank: ${bank['bankName']} (${bank['bankId']}) → Type: $type');
        if (grouped.containsKey(type)) {
          grouped[type]!.add(bank);
        }
      }

      // Sort each group alphabetically by bank name
      grouped.forEach((key, banks) {
        banks.sort(
          (a, b) =>
              (a['bankName'] as String).compareTo(b['bankName'] as String),
        );
        print('📊 $key Banks: ${banks.length}');
      });

      return grouped;
    } catch (e) {
      print('Error grouping banks: $e');
      return {'Local': [], 'Islamic': [], 'Foreign': []};
    }
  }

  /// Get all banks sorted and grouped by type with section headers
  static Future<List<dynamic>> getBanksWithSections() async {
    try {
      final grouped = await getBanksByType();
      final List<dynamic> result = [];

      final typeOrder = ['Local', 'Islamic', 'Foreign'];

      for (String type in typeOrder) {
        if (grouped[type]!.isNotEmpty) {
          result.add({'type': 'section', 'title': type});
          result.addAll(grouped[type]!);
        }
      }

      // Add Customize section
      result.add({'type': 'section', 'title': 'Customize'});
      result.add({
        'bankId': 'CUSTOM',
        'bankName': 'Add Custom Bank',
        'bankIcon': null,
        'bankType': 'Customize',
        'isCustom': true,
      });

      return result;
    } catch (e) {
      print('Error getting banks with sections: $e');
      return [];
    }
  }

  /// Insert bank data (useful for initial setup)
  static Future<void> insertBanks(List<Map<String, dynamic>> banks) async {
    try {
      await Supabase.instance.client.from(tableName).insert(banks);
      print('Banks inserted successfully');
    } catch (e) {
      print('Error inserting banks: $e');
    }
  }

  /// Upload bank icon to storage
  static Future<String?> uploadBankIcon(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      await Supabase.instance.client.storage
          .from(bucketName)
          .uploadBinary(
            '$bankIconFolder/$fileName',
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return fileName;
    } catch (e) {
      print('Error uploading bank icon: $e');
      return null;
    }
  }
}
