import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

/// Upload bank icons to Supabase S3 storage
/// This script uploads all bank logos from assets/AccountLogo to the 'images' bucket
/// in the 'bank_icon' folder using the S3-compatible endpoint
Future<void> uploadBankIconsToS3() async {
  final supabase = Supabase.instance.client;

  // Define the asset directories mapping
  final baseDir = Directory('assets/AccountLogo');
  final directories = {
    'LocalBank': 'Local',
    'IslamicBank': 'Islamic',
    'ForeignBank': 'Foreign',
  };

  print('Starting bank icon upload to Supabase S3...');
  print('Target: images bucket -> bank_icon folder');
  print(
    'Endpoint: https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3\n',
  );

  int successCount = 0;
  int failureCount = 0;

  try {
    for (final entry in directories.entries) {
      final dirName = entry.key;
      final dirPath = '${baseDir.path}/$dirName';
      final directory = Directory(dirPath);

      if (!directory.existsSync()) {
        print('⚠ Directory not found: $dirPath');
        continue;
      }

      print('Uploading from $dirName...');

      final files = directory.listSync();

      for (final file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          // Upload to bank_icon folder with filename only
          final remotePath = 'bank_icon/$fileName';

          try {
            final fileBytes = await file.readAsBytes();

            await supabase.storage
                .from('images')
                .uploadBinary(
                  remotePath,
                  fileBytes,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: true,
                  ),
                );

            print('  ✓ Uploaded: $fileName');
            successCount++;
          } catch (e) {
            print('  ✗ Failed to upload $fileName: $e');
            failureCount++;
          }
        }
      }
    }

    print('\n' + '=' * 50);
    print('Upload Summary:');
    print('✓ Successful: $successCount');
    print('✗ Failed: $failureCount');
    print('=' * 50);

    // Print the URL pattern for reference
    print('\nBank icons are now available at:');
    print(
      'https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3/images/bank_icon/[filename]',
    );
    print(
      '\nExample: https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3/images/bank_icon/AMBANK.png',
    );
  } catch (e) {
    print('Error during upload: $e');
  }
}

void main() async {
  print('═' * 60);
  print('Bank Icon Upload Utility (S3-Compatible Storage)');
  print('═' * 60);
  print('This script uploads all bank logos from assets/AccountLogo');
  print('to the Supabase S3-compatible storage bucket.');
  print('\nConfiguration:');
  print('  • Bucket: images');
  print('  • Folder: bank_icon');
  print(
    '  • Endpoint: https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3',
  );
  print('\nMake sure you have Supabase initialized before running this.');
  print('═' * 60 + '\n');

  await uploadBankIconsToS3();
}
