/// Helper class for managing bank icons from Supabase storage
/// Uses S3-compatible storage endpoint
class BankIconHelper {
  static const String storageEndpoint =
      'https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3';
  static const String bucketName = 'images';
  static const String bankIconFolder = 'bank_icon';

  /// Get the Supabase URL for a bank icon
  static String getBankIconUrl(String? iconFileName) {
    if (iconFileName == null || iconFileName.isEmpty) {
      return '';
    }

    // If it's already a full URL, return it
    if (iconFileName.startsWith('http')) {
      return iconFileName;
    }

    // Build URL using S3-compatible endpoint
    return '$storageEndpoint/$bucketName/$bankIconFolder/$iconFileName';
  }
}
