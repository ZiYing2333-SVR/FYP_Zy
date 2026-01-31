# Bank Database Implementation Guide

## Overview
This guide explains how to implement bank data storage in Supabase and integrate it with your Flutter app. Bank information is now stored in a database table instead of being hardcoded, allowing for dynamic updates and scalability.

## Architecture

```
Database (Bank Table)
    ↓
BankService (Queries Database)
    ↓
AddAccountPage2 (Displays Banks from DB)
    ↓
BankIconHelper (Generates Icon URLs)
    ↓
Supabase Storage (images/bank_icon/)
```

## Step 1: Create Bank Table in Supabase

### Option A: Using SQL Migration (Recommended)
1. Open Supabase Dashboard → SQL Editor
2. Create a new query
3. Copy content from: `supabase/migrations/seed_banks.sql`
4. Click "Run" to execute

This will:
- ✅ Create the `Bank` table with proper schema
- ✅ Create indexes for fast queries
- ✅ Insert all 50+ bank records (Local, Islamic, Foreign)

### Option B: Manual Table Creation
1. Go to Supabase → SQL Editor
2. Run this SQL:
```sql
CREATE TABLE IF NOT EXISTS public."Bank" (
  "bankId" character varying NOT NULL,
  "bankName" character varying NOT NULL,
  "bankType" character varying NULL DEFAULT 'Local',
  "bankIcon" character varying NULL,
  constraint "Bank_pkey" primary key ("bankId")
) TABLESPACE pg_default;

CREATE INDEX idx_bank_type ON public."Bank" ("bankType");
CREATE INDEX idx_bank_name ON public."Bank" ("bankName");
```

3. Then insert bank data using the seed SQL script

## Step 2: Verify Table & Data

1. Open Supabase Dashboard → Database → Tables
2. Click on "Bank" table
3. You should see 50+ rows with:
   - `bankId`: Unique identifier (e.g., LOCAL_MAYBANK, ISLAMIC_AFFIN)
   - `bankName`: Display name (e.g., "Maybank", "Affin Islamic Bank")
   - `bankType`: Category (Local, Islamic, or Foreign)
   - `bankIcon`: File name (e.g., "MAYBANK.png")

### Example Bank Records
```
| bankId         | bankName        | bankType | bankIcon      |
|----------------|-----------------|----------|---------------|
| LOCAL_MAYBANK  | Maybank         | Local    | MAYBANK.png   |
| ISLAMIC_AFFIN  | Affin Islamic   | Islamic  | AffinIslamicBank.png |
| FOREIGN_HSBC   | HSBC Bank       | Foreign  | HSBCBank.png  |
```

## Step 3: Upload Bank Icons to Supabase Storage

### Prerequisites
- Icons need to be uploaded to: `images/bank_icon/` folder in Supabase storage
- Storage bucket name: `images` (must be PUBLIC)

### Steps
1. **Create Storage Bucket** (if not exists):
   - Supabase Dashboard → Storage
   - Create new bucket: `images`
   - Set to **Public** access level

2. **Create Folder Structure**:
   - Create folder: `bank_icon` inside `images` bucket

3. **Upload Bank Icons** - Choose one method:

#### Method A: Manual Upload via Dashboard
1. Go to Supabase Storage → images → bank_icon
2. Drag & drop all PNG/JPG files from:
   - `assets/AccountLogo/LocalBank/*.png`
   - `assets/AccountLogo/IslamicBank/*.{png,jpg}`
   - `assets/AccountLogo/ForeignBank/*.{png,webp}`

#### Method B: Using Supabase CLI
```bash
# Install Supabase CLI if not done
npm install -g supabase

# Link your project
supabase link --project-ref drohtvfhklvqoeokopey

# Upload all bank icons
supabase storage cp assets/AccountLogo/LocalBank/* storage/images/bank_icon/ --recursive
supabase storage cp assets/AccountLogo/IslamicBank/* storage/images/bank_icon/ --recursive
supabase storage cp assets/AccountLogo/ForeignBank/* storage/images/bank_icon/ --recursive
```

#### Method C: Using BankService Upload Function
```dart
// In your app, call this once:
await BankService.uploadBankIcon(filePath, 'MAYBANK.png');
```

## Step 4: Architecture Components

### BankService (`lib/services/bank_service.dart`)
Handles all database operations:
```dart
// Fetch all banks
final banks = await BankService.getAllBanks();

// Fetch banks grouped by type
final grouped = await BankService.getBanksByType();
// Returns: {'Local': [...], 'Islamic': [...], 'Foreign': [...]}

// Get icon URL
final url = BankService.getBankIconUrl('MAYBANK.png');
// Returns: https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3/images/bank_icon/MAYBANK.png
```

### BankIconHelper (`lib/utils/bank_icon_helper.dart`)
Converts bank icon file names to full URLs:
```dart
String url = BankIconHelper.getBankIconUrl('MAYBANK.png');
// Constructs S3-compatible URL automatically
```

### AddAccountPage2 Updates
- Fetches banks from database on load
- Filters by type (Local, Islamic, Foreign)
- Displays bank icons from Supabase
- Smooth loading state

## Step 5: Usage in Your App

### Display Bank List
```dart
import 'package:app/services/bank_service.dart';

// Get all banks
final banks = await BankService.getAllBanks();

// Get banks by type
final grouped = await BankService.getBanksByType();
final localBanks = grouped['Local'] ?? [];
```

### Display Bank Icons
```dart
import 'package:app/utils/bank_icon_helper.dart';

final iconUrl = BankIconHelper.getBankIconUrl(bank['bankIcon']);
Image.network(
  iconUrl,
  errorBuilder: (context, error, stackTrace) {
    return Icon(Icons.account_balance_wallet);
  },
)
```

## File Structure

```
lib/
├── services/
│   └── bank_service.dart          # Database operations
├── utils/
│   └── bank_icon_helper.dart      # URL generation
├── constants/
│   └── bank_seed_data.dart        # Bank data reference
└── screens/
    └── add_account_page2.dart     # Bank selection UI

supabase/
└── migrations/
    └── seed_banks.sql             # Database migration
```

## Troubleshooting

### Banks Not Loading
1. ✅ Verify Bank table exists and has data
2. ✅ Check Supabase connection
3. ✅ Check if user has access to read Bank table

### Icons Not Showing
1. ✅ Verify `images` bucket exists and is PUBLIC
2. ✅ Check if bank icons are in `images/bank_icon/` folder
3. ✅ Verify file names match database `bankIcon` values

### Permission Denied Error
1. Go to Supabase → Storage → images
2. Click RLS (Row Level Security)
3. Ensure "SELECT" policy allows public access:
```sql
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'images');
```

## Adding New Banks

To add new bank to the system:

1. **Add bank icon to storage**:
   - Upload to: `images/bank_icon/NEWBANK.png`

2. **Add to database**:
```sql
INSERT INTO public."Bank" ("bankId", "bankName", "bankType", "bankIcon")
VALUES ('NEW_BANK', 'New Bank Name', 'Local', 'NEWBANK.png');
```

3. **App updates automatically** (no code changes needed!)

## Performance Considerations

### Database Queries
- Banks are fetched once on page load
- Results are cached in app state
- Minimal queries to database

### Storage
- Icons cached by Image.network widget
- S3-compatible endpoint for fast delivery
- CDN enabled by Supabase

### Optimization
- Use `bankType` index for filtering
- Query only needed fields
- Paginate if > 1000 banks

## Security

### Row Level Security (RLS)
Enable RLS on Bank table:
```sql
-- Allow everyone to read
ALTER TABLE public."Bank" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Bank table public read"
ON public."Bank" FOR SELECT
USING (true);
```

### Storage Security
- Bank icons are public (no secrets in filenames)
- User cannot modify storage (app only reads)
- All updates through admin backend

## Next Steps

1. ✅ Create Bank table with SQL migration
2. ✅ Upload bank icons to storage
3. ✅ Test bank loading in app
4. ✅ Handle edge cases (offline, errors)
5. ✅ Add bank management admin panel

## API Reference

### BankService Methods

#### `getAllBanks()`
```dart
Future<List<Map<String, dynamic>>> getAllBanks()
```
Fetches all banks from database

#### `getBanksByType()`
```dart
Future<Map<String, List<Map<String, dynamic>>>> getBanksByType()
```
Returns banks grouped by bankType

#### `getBankIconUrl(String? iconPath)`
```dart
String getBankIconUrl(String? iconPath)
```
Converts icon filename to full S3 URL

## Testing

Test bank functionality:
```dart
// Test database connection
final banks = await BankService.getAllBanks();
expect(banks.length, greaterThan(0));

// Test icon URL generation
final url = BankIconHelper.getBankIconUrl('MAYBANK.png');
expect(url.startsWith('https://'), true);

// Test filtering
final local = await BankService.getBanksByType();
expect(local['Local'].length, 8);
```
