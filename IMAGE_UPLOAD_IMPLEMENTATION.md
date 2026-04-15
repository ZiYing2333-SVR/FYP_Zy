# Image Upload Implementation for Transactions & Transfers

## Overview
Image upload functionality has been implemented for all three transaction types (Expense, Income, and Transfer) in the `add_transaction.dart` page. Images are stored in Supabase storage and their URLs are saved in the database.

---

## Storage Structure

### Supabase Storage Bucket
- **Bucket Name:** `images`
- **Folder Path:** `transaction_image/`
- **File Naming Pattern:** `{PREFIX}_{userId}_{timestamp}.{extension}`

### File Naming Convention
| Transaction Type | Prefix | Example |
|---|---|---|
| Expense | `TRANS` | `TRANS_user123_1713177600000.jpg` |
| Income | `TRANS` | `TRANS_user123_1713177600001.png` |
| Transfer | `TRNS` | `TRNS_user123_1713177600002.jpg` |

### Supported File Extensions
- `.jpg` / `.jpeg`
- `.png`
- `.gif`
- `.webp`
- Other formats automatically converted to `.jpg`

---

## Database Storage

### Transaction Table
- **Column:** `image` (character varying)
- **Content:** Public URL to the uploaded image
- **Nullable:** Yes
- **Example:** `https://your-supabase-url/storage/v1/object/public/images/transaction_image/TRANS_user123_1713177600000.jpg`

### Transfer Table
- **Column:** `noteImage` (character varying)
- **Content:** Public URL to the uploaded image
- **Nullable:** Yes
- **Example:** `https://your-supabase-url/storage/v1/object/public/images/transaction_image/TRNS_user123_1713177600000.jpg`

---

## Implementation Details

### Image Upload Process

```dart
// 1. Extract file extension
final fileExtension = _selectedImage!.path.split('.').last.toLowerCase();

// 2. Validate and set extension (defaults to .jpg if invalid)
final validExtension = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension)
    ? fileExtension
    : 'jpg';

// 3. Generate unique filename with type prefix
final prefix = _selectedType == 'transfer' ? 'TRNS' : 'TRANS';
final fileName = '${prefix}_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.$validExtension';
final filePath = 'transaction_image/$fileName';

// 4. Upload to Supabase
await Supabase.instance.client.storage
    .from('images')
    .upload(filePath, file);

// 5. Get public URL
imageUrl = Supabase.instance.client.storage
    .from('images')
    .getPublicUrl(filePath);

// 6. Store URL in database
// For transactions: Store in 'image' column
// For transfers: Store in 'noteImage' column
```

### Error Handling
- Image upload errors are caught separately to prevent transaction loss
- User receives error dialog with detailed error message
- Transaction is not saved if image upload fails (returns early)
- Detailed console logging for debugging

### Features
✅ Unique file naming prevents collisions  
✅ Type-specific prefixes for easy organization  
✅ File extension validation and conversion  
✅ Error handling with user feedback  
✅ Debug logging for troubleshooting  
✅ Works for all three transaction types  
✅ Null-safe handling (image is optional)  

---

## Usage in Transaction Detail Pages

### Display Transaction Images
```dart
// Read image URL from Transaction.image column
if (transaction['image'] != null && transaction['image'].isNotEmpty) {
  Image.network(
    transaction['image'],
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) {
      return Icon(Icons.image_not_supported);
    },
  );
}
```

### Display Transfer Images
```dart
// Read image URL from Transfer.noteImage column
if (transfer['noteImage'] != null && transfer['noteImage'].isNotEmpty) {
  Image.network(
    transfer['noteImage'],
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) {
      return Icon(Icons.image_not_supported);
    },
  );
}
```

---

## Debugging

### Console Output Examples
```
[AddTransaction] Uploading image: transaction_image/TRANS_user456_1713177600000.jpg
[AddTransaction] Image uploaded successfully: https://...
[AddTransaction] Uploading image: transaction_image/TRNS_user456_1713177604000.png
[AddTransaction] Image uploaded successfully: https://...
```

### Common Issues & Solutions

| Issue | Solution |
|---|---|
| Image upload fails silently | Check console logs for error messages; ensure bucket permissions are correct |
| Image URL not stored in database | Verify `image` (Transaction) or `noteImage` (Transfer) column exists |
| Image displays as broken link | Confirm public URL is accessible; check Supabase bucket policy |
| File extension changed | Invalid extensions are auto-converted to .jpg; this is by design |

---

## Next Steps

1. **Display images in transaction/transfer detail pages** using the examples above
2. **Add image preview** option before saving transactions
3. **Implement image compression** for faster uploads and storage optimization
4. **Add image deletion** functionality when removing transactions/transfers
5. **Support multiple images** per transaction if needed

---

## Related Files
- Implementation: `lib/screens/add_transaction.dart` (lines 620-760)
- Database schema: Transaction table (`image` column), Transfer table (`noteImage` column)
