import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

Future<void> uploadBankIcons() async {
  final supabase = Supabase.instance.client;

  // Define the asset directories
  final baseDir = Directory('assets/AccountLogo');

  // Create subdirectories to upload
  final directories = ['LocalBank', 'IslamicBank', 'ForeignBank'];

  print('Starting bank icon upload to Supabase...');

  try {
    for (final dir in directories) {
      final dirPath = '${baseDir.path}/$dir';
      final directory = Directory(dirPath);

      if (!directory.existsSync()) {
        print('Directory not found: $dirPath');
        continue;
      }

      final files = directory.listSync();

      for (final file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          final remotePath = 'bank_icons/$dir/$fileName';

          try {
            final fileBytes = await file.readAsBytes();

            await supabase.storage
                .from('account-icons')
                .uploadBinary(
                  remotePath,
                  fileBytes,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: true,
                  ),
                );

            print('✓ Uploaded: $remotePath');
          } catch (e) {
            print('✗ Failed to upload $fileName: $e');
          }
        }
      }
    }

    print('Upload completed!');

    // Print the URL pattern for reference
    print('\nBank icons are now available at:');
    print(
      'https://[your-project].supabase.co/storage/v1/object/public/account-icons/bank_icons/[category]/[filename]',
    );
  } catch (e) {
    print('Error during upload: $e');
  }
}

void main() async {
  print('Bank Icon Upload Utility');
  print(
    'This script uploads all bank logos from assets/AccountLogo to Supabase',
  );
  print('Make sure you have Supabase initialized before running this.');
}
