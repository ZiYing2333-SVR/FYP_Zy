# Quick Start - Bank Database Setup (5 Minutes)

## TL;DR - Quick Setup

### 1. Create Database (2 min)
```sql
-- Copy all SQL from: supabase/migrations/seed_banks.sql
-- Paste in Supabase → SQL Editor
-- Click "Run"
```

### 2. Create Storage Bucket (1 min)
```
Supabase Dashboard
├── Storage
├── Create bucket "images"
├── Make PUBLIC
└── Create folder "bank_icon"
```

### 3. Upload Icons (1 min)
```
Storage → images → bank_icon
Drag & drop all PNG files from:
- assets/AccountLogo/LocalBank/
- assets/AccountLogo/IslamicBank/
- assets/AccountLogo/ForeignBank/
```

### 4. Run App (1 min)
```bash
flutter clean
flutter pub get
flutter run
```

Done! ✅

## Verify Setup

### ✅ Bank Table
- Supabase → Database → Tables → Bank
- Should show 50+ rows with bankName, bankType, bankIcon

### ✅ Storage Bucket
- Supabase → Storage → images → bank_icon
- Should show all PNG/JPG files

### ✅ App
- Navigate to: Account Creation → Select Account Type → Select Bank
- Should display banks with icons from database

## What Gets Done Automatically

✅ App fetches banks from database  
✅ Banks grouped by type (Local, Islamic, Foreign)  
✅ Search & filter working  
✅ Icons display from cloud storage  
✅ Works on mobile & web  

## Files to Know

| File | Purpose |
|------|---------|
| `lib/services/bank_service.dart` | Database queries |
| `lib/utils/bank_icon_helper.dart` | Icon URL generation |
| `lib/screens/add_account_page2.dart` | Bank selection UI |
| `supabase/migrations/seed_banks.sql` | Database creation |

## Most Common Issues

### Issue: Banks not showing
**Solution:** Run the SQL migration to create table and seed data

### Issue: Icons blank/broken
**Solution:** Upload icons to `images/bank_icon/` bucket in storage

### Issue: Permission denied
**Solution:** Set `images` bucket to PUBLIC access

## Storage Endpoint

Your icons are at:
```
https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3/images/bank_icon/[filename]
```

Example: `MAYBANK.png` → full URL automatically generated

## Testing Locally

```bash
# Build
flutter run

# Expected behavior:
# 1. App loads AddAccountPage2
# 2. Shows loading spinner
# 3. Banks appear from database
# 4. Tap bank → navigate to account creation
# 5. Icons display correctly
```

## Need Help?

Detailed guides available:
- `BANK_DATABASE_SETUP.md` - Full setup with all options
- `BANK_SYSTEM_SUMMARY.md` - Architecture & changes overview
- SQL file: `supabase/migrations/seed_banks.sql` - All SQL commands

---

**That's it!** Your bank system is now database-driven. 🎉
