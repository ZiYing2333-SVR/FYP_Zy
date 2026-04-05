# Account Grouping Feature Implementation Guide

## Overview

The account grouping feature allows users to organize their accounts into custom groups for better management and visibility. Users can create multiple groups, assign accounts to each group, and filter the accounts view by group.

## Key Features

✅ **Multiple Account Groups**: Create unlimited custom account groups
✅ **Easy Group Management**: Dropdown interface at the top-left of the account page
✅ **Multi-Account Selection**: Select multiple accounts (excluding Savings type) per group
✅ **Account Filtering**: View only accounts in the selected group
✅ **Quick Group Creation**: "Add Group" button in the dropdown menu
✅ **Edit Groups**: Update group names and account assignments
✅ **Consistent UI**: Follows the app's green color theme

## Database Schema

### AccountCategory Table
Stores group metadata:
```sql
CREATE TABLE public."AccountCategory" (
  "accountCategoryId" character varying NOT NULL PRIMARY KEY,
  name character varying NOT NULL
);
```

**ID Format**: `GACC` + `userId` + `sequence` (e.g., `GACCUID000101`)

### GroupAccount Table
Maps accounts to groups:
```sql
CREATE TABLE public."GroupAccount" (
  "accountCategoryId" character varying NOT NULL (FK),
  "accountId" character varying NOT NULL (FK),
  PRIMARY KEY ("accountCategoryId", "accountId")
);
```

### Account Table (Updated)
Now includes grouping support:
```sql
ALTER TABLE "Account" 
ADD COLUMN "accountCategoryId" character varying 
FOREIGN KEY REFERENCES "AccountCategory"("accountCategoryId");
```

## User Interface Components

### 1. Account Page Header

**Group Dropdown** (Top-Left):
- Default: "All" - displays all user's accounts
- Shows list of all created groups
- "+" button at bottom to create new group
- Updates display when group is selected

**Add Account Button** (Top-Right):
- Original functionality preserved
- Navigate to account creation page

### 2. Create/Edit Group Screen

**Components**:
- **Back Button (X)**: Close without saving
- **Title**: "Create Group" or "Edit Group"
- **Save Button**: Top-right action button
- **Name Field**: Text input for group name
- **Accounts Section**: 
  - "Add Account" button to open selection
  - Selected accounts display as green chips with remove (X) button
- **Confirm Button**: Bottom button to save and return

**Account Selection Modal**:
- Shows all non-Savings accounts (accountType != "Savings")
- Multi-select with checkboxes
- Organized list with account name and type
- Save button to confirm selection
- Selected accounts carry over to form

## Flutter Files

### New Files Created

#### `lib/screens/create_account_group_screen.dart`
Main screen for creating and editing account groups.

**Key Classes**:
- `CreateAccountGroupScreen`: StatefulWidget
- `_CreateAccountGroupScreenState`: State management

**Key Methods**:
- `_fetchAccounts()`: Load all non-Savings accounts
- `_fetchGroupAccounts()`: Load existing group's accounts
- `_getNextGroupSequence()`: Generate sequential group ID
- `_saveGroup()`: Save group to AccountCategory and GroupAccount tables
- `_showAccountSelectionModal()`: Display multi-select account picker

**State Variables**:
```dart
late TextEditingController _groupNameController;
List<Map<String, dynamic>> _allAccounts = [];
Set<String> _selectedAccountIds = {};
bool _isLoading = true;
bool _isCreating = false;
```

### Updated Files

#### `lib/screens/account_page.dart`

**Added Imports**:
```dart
import 'create_account_group_screen.dart';
```

**New State Variables**:
```dart
List<Map<String, dynamic>> _filteredAccounts = [];
List<Map<String, dynamic>> _accountGroups = [];
String _selectedGroupId = 'all';
String _selectedGroupName = 'All';
```

**New Methods**:
- `_fetchAccountGroups()`: Load user's groups from AccountCategory table
- Async `onSelected` callback in PopupMenuButton for filtering accounts

**Modified Build Method**:
- Replaced "Group A" container with PopupMenuButton
- Added dynamic group list generation
- Implemented account filtering based on selected group
- Updated savings and other account displays to use filtered accounts

**PopupMenuButton Features**:
- "All" option - shows all accounts
- Dynamic group list from database
- "Add Group" option with + icon at bottom
- Divider between groups and add action

## User Workflow

### Creating a New Group

1. **Step 1**: Click "All" dropdown on Account page
2. **Step 2**: Select "+ Add Group" option
3. **Step 3**: Enter group name (e.g., "Daily Accounts")
4. **Step 4**: Click "Add Account" button
5. **Step 5**: Select accounts from modal (multi-select)
6. **Step 6**: Click "Save" in modal
7. **Step 7**: Selected accounts appear as green chips
8. **Step 8**: Click "Confirm" button
9. **Step 9**: Group is created and list refreshes
10. **Step 10**: Group becomes available in dropdown

### Editing a Group

1. Click dropdown and select the group
2. Click "+ Add Group" (future enhancement to show "Edit Group" option)
3. Repeat steps 3-9 above

### Switching Groups

1. Click dropdown on Account page
2. Select desired group
3. Account display immediately filters to show only selected group accounts
4. Savings and other account sections update accordingly

### Removing an Account from Group

1. Open Create/Edit Group screen
2. Click "X" on the green chip of account to remove
3. Click "Confirm" to save

## Technical Implementation Details

### Group ID Generation Algorithm

```dart
String accountCategoryId = 'GACC${widget.userId}$seqFormatted';
// Format: GACC + userId + 2-digit sequence
// Example: GACCUID000101 (for user UID0001, 1st group)
```

**Sequence Logic**:
1. Query AccountCategory table for matching pattern
2. Find last created group ID for user
3. Extract sequence number
4. Increment and pad with leading zeros
5. Return formatted ID

### Account Filtering Logic

```dart
// When group selected:
if (value == 'all') {
  _filteredAccounts = _accounts;
} else {
  // Fetch from GroupAccount table
  final groupAccounts = await Supabase...
    .select('accountId')
    .eq('accountCategoryId', value);
  
  // Filter display accounts
  _filteredAccounts = _accounts
    .where((account) => groupAccountIds.contains(account['accountId']))
    .toList();
}
```

### Account Restrictions

Non-Savings accounts only:
- **Included**: Debit, Credit Card, E-Wallet, Bank, etc.
- **Excluded**: Savings type accounts (not available for group assignment)

**Why?**: Savings accounts are special - they're linked to saving goals and have different lifecycle rules.

## Data Flow

### Creating Group Flow

```
User Input (Flutter)
        ↓
Create Group Screen (FormSubmission)
        ↓
Generate ID (GACC + UserId + Seq)
        ↓
Insert AccountCategory (name + ID)
        ↓
Insert GroupAccount Records (FK references)
        ↓
Update UI (Refresh dropdown)
```

### Filtering Flow

```
User Selects Group (Dropdown)
        ↓
Fetch GroupAccount Records
        ↓
Build AccountId Set
        ↓
Filter _accounts by Set
        ↓
Update _filteredAccounts State
        ↓
Rebuild UI with Filtered Accounts
```

## Supabase Queries

### Fetch All User Groups

```dart
final response = await Supabase.instance.client
    .from('AccountCategory')
    .select()
    .ilike('accountCategoryId', 'GACC${userId}%')
    .order('name', ascending: true);
```

### Fetch Group Accounts

```dart
final groupAccounts = await Supabase.instance.client
    .from('GroupAccount')
    .select('accountId')
    .eq('accountCategoryId', accountCategoryId);
```

### Create New Group

```dart
// 1. Insert into AccountCategory
await Supabase.instance.client
    .from('AccountCategory')
    .insert({
      'accountCategoryId': generatedId,
      'name': groupName,
    });

// 2. Insert into GroupAccount (batch)
await Supabase.instance.client
    .from('GroupAccount')
    .insert(groupAccountRecords);
```

### Update Group

```dart
// 1. Update name
await Supabase.instance.client
    .from('AccountCategory')
    .update({'name': newName})
    .eq('accountCategoryId', groupId);

// 2. Delete old mappings
await Supabase.instance.client
    .from('GroupAccount')
    .delete()
    .eq('accountCategoryId', groupId);

// 3. Insert new mappings
await Supabase.instance.client
    .from('GroupAccount')
    .insert(newGroupAccountRecords);
```

## Error Handling

**Validation Checks**:
- ✓ Group name not empty
- ✓ At least one account selected
- ✓ AccountCategoryId uniqueness
- ✓ Foreign key constraints

**Error Messages**:
- "Please enter a group name"
- "Please select at least one account"
- Database operation errors caught and displayed

## UI Theme

**Colors Used**:
- **Background**: `0xFFFEFFD3` (Light yellow)
- **Primary**: `0xFFA7E399` (Light green)
- **Accent**: `Colors.green.shade100` (Green background)
- **Text**: `Colors.black87` (Dark text)
- **Border**: `Colors.grey[200-400]`

**Typography**:
- **Headers**: 16px, FontWeight.w600
- **Labels**: 14px, FontWeight.w600
- **Body**: 12px, FontWeight.w500
- **Buttons**: 14-16px, FontWeight.w600

## Future Enhancements

🔄 **Possible Improvements**:
1. **Delete Group**: Add delete functionality with confirmation
2. **Rename Group**: Quick rename without re-selecting accounts
3. **Group Statistics**: Show account count and total balance per group
4. **Color per Group**: Assign colors to groups for visual distinction
5. **Smart Groups**: Auto-create groups based on account type
6. **Group Shortcuts**: Quick access buttons on home screen
7. **Import/Export**: Backup and restore group configurations
8. **Search**: Filter groups by name
9. **Sharing**: Share group views (future multi-user feature)
10. **Favorites**: Mark favorite groups for quick access

## Testing Checklist

### Functional Tests

- [ ] Create new group with valid name
- [ ] Create group with multiple accounts
- [ ] Edit existing group (rename)
- [ ] Edit group (change account selection)
- [ ] Delete account from group
- [ ] Select group from dropdown
- [ ] View filtered accounts for group
- [ ] Switch between groups
- [ ] "All" shows all accounts
- [ ] Non-Savings accounts only available for selection
- [ ] Group ID format correct (GACC+UserId+Seq)

### UI Tests

- [ ] Dropdown displays correctly
- [ ] Group list updates after creation
- [ ] Selected accounts show as green chips
- [ ] Remove (X) button works on chips
- [ ] Modal accounts show with checkboxes
- [ ] Selected accounts persist in form
- [ ] Confirm button disabled with empty group
- [ ] Confirm button enabled with accounts

### Data Tests

- [ ] Groups saved to AccountCategory table
- [ ] Accounts saved to GroupAccount table
- [ ] Foreign keys maintain referential integrity
- [ ] No orphaned groups
- [ ] No orphaned group-account mappings
- [ ] Sequence numbers increment correctly

### Edge Cases

- [ ] User with no groups - "All" only
- [ ] Group with single account
- [ ] Edit group to different accounts
- [ ] Rapid group creation
- [ ] Special characters in group name
- [ ] Very long group names

## Troubleshooting

### Issue: Dropdown not showing groups

**Solution**: 
- Check account categories created with correct ID format
- Verify user ID matches in database
- Clear cache and restart app

### Issue: Accounts not filtering

**Solution**:
- Verify GroupAccount table has correct mappings
- Check accountCategoryId in GroupAccount references AccountCategory
- Ensure accountId exists in Account table

### Issue: ID generation creates duplicates

**Solution**:
- Check query correctly filters by userId
- Verify sequence number extraction logic
- Ensure incremental padding works correctly

### Issue: Edit group not showing existing selections

**Solution**:
- Verify _fetchGroupAccounts() is called in initState for edit mode
- Check groupId parameter is passed correctly
- Ensure GroupAccount table has data

## Support Documentation

**User Guide**: Account page help text
**Admin Guide**: Database setup and maintenance
**Developer Guide**: This document

## Version History

- **v1.0** - Initial implementation
  - Create, read groups
  - Multi-select accounts
  - Filter display by group
  - Edit group name and accounts

## Related Features

- **Saving Goals**: Linked to destination accounts in groups
- **Budget Tracking**: Can be organized by account groups
- **Transaction Filtering**: Future enhancement to filter by group
- **Reports**: Group-based spending analysis
