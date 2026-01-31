import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class BankService {
  static const String tableName = 'Bank';
  static const String bucketName = 'images';
  static const String bankIconFolder = 'bank_icon';

  /// Fetch all banks from Supabase database
  static Future<List<Map<String, dynamic>>> getAllBanks() async {
    try {
      final response = await Supabase.instance.client
          .from(tableName)
          .select()
          .order('bankName');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching banks: $e');
      return [];
    }
  }

  /// Get bank icon URL
  static String getBankIconUrl(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return '';
    }

    if (iconPath.startsWith('http')) {
      return iconPath;
    }

    // Use S3-compatible storage URL
    const baseUrl =
        'https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3';
    return '$baseUrl/$bucketName/$bankIconFolder/$iconPath';
  }

  /// Group banks by type (Local, Islamic, Foreign)
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
        final type = bank['bankType'] ?? 'Local';
        if (grouped.containsKey(type)) {
          grouped[type]!.add(bank);
        }
      }

      return grouped;
    } catch (e) {
      print('Error grouping banks: $e');
      return {'Local': [], 'Islamic': [], 'Foreign': []};
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
