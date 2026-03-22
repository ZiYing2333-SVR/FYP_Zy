# Architecture & Flow Diagrams

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Flutter App                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           AddAccountPage2 (UI Layer)                     │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ • Search Bar                                       │  │  │
│  │  │ • Scrollable ListView with Sections               │  │  │
│  │  │   ├── Local Banks (sorted A-Z)                    │  │  │
│  │  │   ├── Islamic Banks (sorted A-Z)                  │  │  │
│  │  │   └── Foreign Banks (sorted A-Z)                  │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                        ↓                                   │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │        BankService (Business Logic)                │  │  │
│  │  │  ┌─────────────────────────────────────────────┐   │  │  │
│  │  │  │ • getAllBanks()                             │   │  │  │
│  │  │  │ • getBanksByType()                          │   │  │  │
│  │  │  │ • getBanksWithSections()  [NEW]             │   │  │  │
│  │  │  │ • getBankIconUrl()                          │   │  │  │
│  │  │  │ • uploadBankIcon()                          │   │  │  │
│  │  │  └─────────────────────────────────────────────┘   │  │  │
│  │  │                        ↓                            │  │  │
│  │  │  ┌─────────────────────────────────────────────┐   │  │  │
│  │  │  │    Supabase Client                          │   │  │  │
│  │  │  │  ┌──────────────────┐  ┌────────────────┐   │   │  │  │
│  │  │  │  │  Database        │  │  S3 Storage    │   │   │  │  │
│  │  │  │  │  (Bank table)     │  │  (bank icons)  │   │   │  │  │
│  │  │  │  └──────────────────┘  └────────────────┘   │   │  │  │
│  │  │  └─────────────────────────────────────────────┘   │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                                ↓
        ┌─────────────────────────────────────────────────────┐
        │  Supabase Backend (Cloud Services)                  │
        │  ┌──────────────────────────────────────────────┐   │
        │  │  PostgreSQL Database                         │   │
        │  │  ┌─────────────────────────────────────────┐ │   │
        │  │  │ Bank Table                              │ │   │
        │  │  │ • bankId (PK)                           │ │   │
        │  │  │ • bankName (indexed)                    │ │   │
        │  │  │ • bankType (Local/Islamic/Foreign)      │ │   │
        │  │  │ • bankIcon (filename)                   │ │   │
        │  │  └─────────────────────────────────────────┘ │   │
        │  │                                              │   │
        │  │  S3 Storage (S3-Compatible)                 │   │
        │  │  ┌─────────────────────────────────────────┐ │   │
        │  │  │ Bucket: images                          │ │   │
        │  │  │ Folder: bank_icon/                      │ │   │
        │  │  │ • AMBANK.png                            │ │   │
        │  │  │ • MAYBANK.png                           │ │   │
        │  │  │ • CIMBBANK.png                          │ │   │
        │  │  │ • ... (all bank logos)                  │ │   │
        │  │  └─────────────────────────────────────────┘ │   │
        │  └──────────────────────────────────────────────┘   │
        │                                                      │
        │  Endpoint: https://drohtvfhklvqoeokopey.storage...  │
        └─────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                       App Initialization                     │
│                                                              │
│  initState() → _loadBankData()                              │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              BankService.getBanksWithSections()              │
│                                                              │
│  1. Call getAllBanks()                                      │
│     ↓ (Fetch from Supabase DB, sorted by bankName)          │
│                                                              │
│  2. Call getBanksByType()                                   │
│     ↓ (Group into Local/Islamic/Foreign)                   │
│     ↓ (Sort each group alphabetically)                      │
│                                                              │
│  3. Build result with sections                              │
│     [{type: 'section', title: 'Local'},                    │
│      {bankId: 'LOCAL_AFFIN', bankName: 'Affin Bank', ...},│
│      {bankId: 'LOCAL_ALLIANCE', ...},                       │
│      {type: 'section', title: 'Islamic'},                  │
│      ...]                                                    │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                  Update UI State                             │
│                                                              │
│  setState(() {                                              │
│    allBanksWithSections = banks;                           │
│    filteredBanksWithSections = banks;                      │
│  });                                                         │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              Render ListView.builder()                       │
│                                                              │
│  For each item in filteredBanksWithSections:               │
│                                                              │
│  IF item.type == 'section'                                 │
│    → Display SectionHeader (Local/Islamic/Foreign)         │
│                                                              │
│  ELSE (it's a bank)                                        │
│    → Get icon URL: BankIconHelper.getBankIconUrl()         │
│    → Display BankItem with:                                │
│       • Bank icon (from S3)                               │
│       • Bank name                                          │
│       • Navigation arrow                                   │
└──────────────────────────────────────────────────────────────┘
```

## Search Flow Diagram

```
User Types in Search Bar
         ↓
onChanged: _filterBanks(query)
         ↓
IF query.isEmpty
  │ → filteredBanksWithSections = allBanksWithSections
  │ → Return (show all)
  ↓
ELSE
  ↓
  Loop through allBanksWithSections:
  ├─ currentSection = null
  │
  ├─ WHILE iterating:
  │  ├─ IF item.type == 'section'
  │  │   └─ currentSection = item.title
  │  │
  │  ├─ ELSE (item is a bank)
  │  │   ├─ IF bankName CONTAINS query OR bankId CONTAINS query
  │  │   │   ├─ IF currentSection not added yet
  │  │   │   │   └─ ADD currentSection header to filtered list
  │  │   │   └─ ADD bank to filtered list
  │  │   └─ ELSE
  │  │       └─ SKIP (doesn't match)
  │
  └─ filteredBanksWithSections = filtered
         ↓
setState() → Rebuild UI with filtered results
         ↓
Render Only Matching Banks with Section Headers
```

## Image Upload Process

```
┌─────────────────────────────────────────────────────┐
│   dart run upload_bank_icons_s3.dart                │
└────────────────────┬────────────────────────────────┘
                     ↓
     ┌───────────────────────────────────┐
     │  For each directory:              │
     │  • LocalBank                      │
     │  • IslamicBank                    │
     │  • ForeignBank                    │
     └────────────────┬────────────────────┘
                      ↓
     ┌───────────────────────────────────┐
     │  For each file in directory:      │
     │                                   │
     │  1. Read file as bytes            │
     │  2. Upload to Supabase S3:        │
     │     path: bank_icon/{filename}    │
     │     bucket: images                │
     │  3. Log result (✓ or ✗)          │
     └────────────────┬────────────────────┘
                      ↓
         ┌─────────────────────────┐
         │  Upload Summary         │
         │  ✓ Successful: X        │
         │  ✗ Failed: Y            │
         │                         │
         │  Available at:          │
         │  {endpoint}/images/     │
         │  bank_icon/{filename}   │
         └─────────────────────────┘
```

## State Management

```
┌─────────────────────────────────────────────────────────┐
│                    _AddAccountPage2State                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Private Variables:                                    │
│  ┌──────────────────────────────────────────────────┐ │
│  │ List<dynamic> allBanksWithSections              │ │
│  │   → Original data from service (all banks)      │ │
│  │                                                  │ │
│  │ List<dynamic> filteredBanksWithSections         │ │
│  │   → Currently displayed data (filtered if       │ │
│  │     search active, all if no search)            │ │
│  │                                                  │
│  │ TextEditingController _searchController         │ │
│  │   → Controls search input field                 │ │
│  │                                                  │
│  │ bool isLoading                                  │
│  │   → Shows loading indicator while fetching      │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
│  Methods:                                              │
│  ┌──────────────────────────────────────────────────┐ │
│  │ initState()                                      │ │
│  │   → Load bank data on widget creation            │ │
│  │                                                  │
│  │ _loadBankData()                                 │ │
│  │   → Fetch banks from service                    │ │
│  │   → Update state (setState)                     │ │
│  │                                                  │
│  │ _filterBanks(String query)                      │ │
│  │   → Filter banks based on search query          │ │
│  │   → Maintain section headers in results         │ │
│  │   → Update state (setState)                     │ │
│  │                                                  │
│  │ dispose()                                        │ │
│  │   → Cleanup controller on widget destroy        │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## UI Component Hierarchy

```
Scaffold
├── backgroundColor: #FFFFD3
└── body: Padding
    └── Column
        ├── SizedBox (spacing)
        │
        ├── Row (Header)
        │   ├── GestureDetector (back button)
        │   ├── Text ("Select Bank")
        │   └── SizedBox (spacing)
        │
        ├── SizedBox (spacing)
        │
        ├── Container (Search Bar)
        │   └── Row
        │       ├── Icon (search)
        │       └── TextField
        │
        ├── SizedBox (spacing)
        │
        └── Expanded
            └── ListView.builder
                ├── FOR each filteredBanksWithSections
                │   ├── IF section header
                │   │   └── Text (section title)
                │   │
                │   └── ELSE (bank item)
                │       └── GestureDetector
                │           └── Container
                │               └── Row
                │                   ├── Container (icon)
                │                   ├── SizedBox
                │                   ├── Expanded (bank name)
                │                   └── Icon (arrow)
                │
                └── "Add Custom Bank" item
```

## Database Schema (Bank Table)

```
┌──────────────────────────────────────────────────┐
│              Bank Table (Supabase)                │
├──────────────────────────────────────────────────┤
│ Column Name     │ Type       │ Properties         │
├─────────────────┼────────────┼────────────────────┤
│ id              │ UUID       │ PK                 │
│ bankId          │ TEXT       │ UNIQUE             │
│ bankName        │ TEXT       │ INDEXED (sort)     │
│ bankType        │ TEXT       │ (Local/Islamic/    │
│                 │            │  Foreign)          │
│ bankIcon        │ TEXT       │ (filename)         │
│ created_at      │ TIMESTAMP  │ DEFAULT now()      │
│ updated_at      │ TIMESTAMP  │                    │
└──────────────────────────────────────────────────┘

Example Rows (after sorting):
┌──────────────┬──────────────┬────────────┬────────────┐
│ bankId       │ bankName     │ bankType   │ bankIcon   │
├──────────────┼──────────────┼────────────┼────────────┤
│ LOCAL_AFFIN  │ Affin Bank   │ Local      │ AFFIN...   │
│ LOCAL_AM     │ AM Bank      │ Local      │ AMBANK.png │
│ LOCAL_CIMB   │ CIMB Bank    │ Local      │ CIMBBANK.. │
│ ...          │ ...          │ ...        │ ...        │
└──────────────┴──────────────┴────────────┴────────────┘
```

## S3 Storage Structure

```
Supabase S3 Bucket: images
│
└── bank_icon/
    ├── AMBANK.png
    ├── AFFINBANK.png
    ├── ALLIANCEBANK.png
    ├── CIMBBANK.png
    ├── HONGLEONGBANK.png
    ├── MAYBANK.png
    ├── PUBLICBANK.png
    ├── RHBBANK.png
    ├── BANKISLAM.png
    ├── CIMBISLAMIC.png
    ├── HONGKONG.png
    ├── HSBC.png
    ├── CITIBANK.png
    └── ... (all bank icons)

Endpoint: https://drohtvfhklvqoeokopey.storage.supabase.co/storage/v1/s3
URL Pattern: {endpoint}/images/bank_icon/{filename}
```

## Sequence Diagram: User Selects Bank

```
User                  App                  BankService            Supabase
  │                    │                        │                    │
  │─ Start ────────────→│                        │                    │
  │                    │─ initState() ──────────│                    │
  │                    │─ _loadBankData() ──────│                    │
  │                    │                        │─ getAllBanks() ────→│
  │                    │                        │←─ [banks] ─────────│
  │                    │                        │─ getBanksByType() ──│
  │                    │                        │ (sort & group)      │
  │                    │                        │─ getBanksWithSections()
  │                    │←─ setState() ──────────│                    │
  │                    │─ Rebuild UI ────────────                    │
  │                    │ (show sections) ──────→│                    │
  │ [See bank list]    │                        │                    │
  │                    │                        │                    │
  │─ Search "Maybank" →│                        │                    │
  │                    │─ _filterBanks() ──────→│                    │
  │                    │ (filter & rebuild)     │                    │
  │ [See filtered]     │←─ setState() ──────────│                    │
  │                    │                        │                    │
  │─ Click on bank ───→│                        │                    │
  │                    │─ Navigate to────→ AddAccountPage3          │
  │                    │   Page3               │                    │
  │                    │                        │                    │
  └────────────────────┘                        │                    │
```

---

These diagrams provide a complete overview of the system architecture, data flow, and component relationships for the bank list implementation.
