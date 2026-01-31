# Bank Icons Upload Guide

## Overview
Bank icons have been migrated from local assets to Supabase Cloud Storage to ensure they display correctly on mobile devices (Android/iOS). This solves the issue where icons showed on web but not on mobile.

## Steps to Complete Setup

### 1. Create Supabase Storage Bucket
First, create a new storage bucket in your Supabase project:

1. Go to Supabase Dashboard → Storage
2. Create a new bucket named: `account-icons`
3. Set it to **Public** (allow public access to read files)
4. Leave other settings as default

### 2. Upload Bank Icons Using Flutter

Option A: Using Helper Function (Recommended)
```dart
// In your Flutter app, add this to a setup screen or initialization
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

Future<void> uploadBankIcons() async {
  final supabase = Supabase.instance.client;
  
  final baseDir = Directory('assets/AccountLogo');
  final directories = ['LocalBank', 'IslamicBank', 'ForeignBank'];
  
  print('Starting bank icon upload...');
  
  for (final dir in directories) {
    final dirPath = '${baseDir.path}/$dir';
    final directory = Directory(dirPath);
    
    if (!directory.existsSync()) continue;
    
    for (final file in directory.listSync()) {
      if (file is File) {
        final fileName = file.path.split('/').last;
        final remotePath = 'bank_icons/$dir/$fileName';
        
        try {
          final fileBytes = await file.readAsBytes();
          
          await supabase.storage.from('account-icons').uploadBinary(
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
}
```

Option B: Using Supabase CLI
```bash
# First, make sure you have Supabase CLI installed
# https://github.com/supabase/cli

# Log in to Supabase
supabase link --project-ref [your-project-ref]

# Upload the entire AccountLogo folder
supabase storage cp assets/AccountLogo/LocalBank/* storage/account-icons/bank_icons/LocalBank/ --recursive
supabase storage cp assets/AccountLogo/IslamicBank/* storage/account-icons/bank_icons/IslamicBank/ --recursive
supabase storage cp assets/AccountLogo/ForeignBank/* storage/account-icons/bank_icons/ForeignBank/ --recursive
```

Option C: Manual Upload via Supabase Dashboard
1. Go to Supabase Dashboard → Storage → account-icons
2. Create folder structure:
   - `bank_icons/LocalBank/`
   - `bank_icons/IslamicBank/`
   - `bank_icons/ForeignBank/`
3. Upload files from `assets/AccountLogo/` to corresponding folders

### 3. Verify Bank Icon Helper
Check that the `lib/utils/bank_icon_helper.dart` file exists and contains the bank list with proper image paths.

### 4. Update pubspec.yaml (if needed)
Make sure you have the latest supabase_flutter package:
```yaml
dependencies:
  supabase_flutter: ^2.0.0  # or latest version
```

## How It Works

### Updated Image Loading Logic
- **Bank Icons (AccountLogo/*)**: Now load from Supabase using `Image.network()`
- **Custom Icons**: Continue to load from Supabase (user-uploaded)
- **Asset Icons**: Still load from assets directory as fallback
- **Error Handling**: Shows wallet icon if image fails to load

### Bank Icon URL Format
```
https://[your-project-id].supabase.co/storage/v1/object/public/account-icons/bank_icons/[category]/[filename]
```

Example:
```
https://abcdef123456.supabase.co/storage/v1/object/public/account-icons/bank_icons/LocalBank/MAYBANK.png
```

## Files Updated
1. `lib/screens/account_page.dart` - Updated `_buildIconImage()` method
2. `lib/screens/edit_account_page.dart` - Updated `_buildIconImage()` method
3. `lib/screens/account_manager.dart` - Updated `_buildIconImage()` method
4. `lib/utils/bank_icon_helper.dart` - New helper class for URL generation

## Testing

### Test on Mobile
1. Build and run on physical Android/iOS device
2. Navigate to Add Account page
3. Select a bank - icon should now display
4. Navigate to Account Page - all bank icons should display

### Test on Web
- Should continue to work as before
- May use cached versions of icons from first load

## Troubleshooting

### Icons still not showing on mobile
1. **Check Bucket Permissions**: Ensure `account-icons` bucket is set to **Public**
2. **Verify Upload**: Go to Supabase Dashboard → Storage and confirm files exist
3. **Check Network**: Ensure device has internet connectivity
4. **Clear Cache**: Rebuild Flutter app with `flutter clean && flutter pub get`

### Mixed display (some show, some don't)
- This usually means not all files were uploaded successfully
- Re-run the upload process for the specific category

### Performance Issues
- Icons are cached by the network image widget
- First load may be slower on slower connections
- Consider adding loading skeleton/placeholder during load

## Optional: Fallback Approach
If you want to keep both local assets AND Supabase URLs for better offline support:

```dart
Future<String> getBankIconUrl(String imagePath) async {
  try {
    final url = BankIconHelper.getBankIconUrl(imagePath);
    // Try to load from network first
    await precacheImage(NetworkImage(url), context);
    return url;
  } catch (e) {
    // Fallback to asset
    return imagePath;
  }
}
```

## Summary
Bank icons will now:
✅ Display correctly on mobile devices
✅ Load from Supabase Cloud Storage
✅ Have proper caching (3600 seconds)
✅ Show wallet icon on error as fallback
✅ Work offline if previously cached
