# Shared Bottom Navigation Bar - System README

## 📌 Overview

The **Shared Bottom Navigation Bar** is a reusable navigation component used throughout the FYP (Finance & Pet System) application. It appears at the bottom of the screen and allows users to navigate between 5 main sections of the app. This component is shared across all major pages to provide consistent navigation.

---

## 🎯 Purpose

This component serves as the **main navigation hub** for the entire application, replacing the standard page-to-page navigation. Instead of traditional buttons or menus, users tap on icons at the bottom to jump between different app sections quickly and easily.

---

## 📱 Navigation Sections

The bottom navigation bar contains **5 main sections**:

| Icon | Label | Purpose | What It Does |
|------|-------|---------|-------------|
| 🏠 | **Home** | Dashboard | Shows overall financial summary, transactions, and alerts |
| 💳 | **Account** | Account Management | View, create, and manage your bank accounts and e-wallets |
| 🐾 | **Pet** | Virtual Pet System | Interact with your virtual pet (gamification feature) |
| 💰 | **Saving** | Savings Goals | Create and track savings goals, manage savings accounts |
| ⚙️ | **Setting** | Settings | Configure app preferences, currency, security, etc. |

---

## 🔄 How It Works

### 1. **Basic Navigation Flow**

```
User taps icon at bottom
           ↓
System checks current location
           ↓
If NOT already on that page → Navigate to new page
If already on that page → Do nothing (prevent reload)
           ↓
Page loads with user data
```

### 2. **Page Replacement (Not Stacking)**

The component uses **`Navigator.pushReplacement()`** instead of regular push:
- ✅ **Replaces** the current page instead of stacking on top
- ✅ Prevents back button confusion
- ✅ Keeps the navigation history clean
- ✅ Better memory management

---

## 🐾 Special: Pet Navigation Logic

The **Pet section** has special handling because it needs to check something first:

### Pet Navigation Workflow

```
User taps "Pet" icon
           ↓
System queries Supabase database:
"Does this user have a pet?"
           ↓
        ╱─────────────────────╲
       YES                    NO
        │                      │
       ↓                      ↓
Go to Pet Home Page    Go to Pet Creation Page
(View existing pet)    (Create new pet first)
```

### Why This Logic?

- If user **has a pet** → Shows their pet profile/home page
- If user **doesn't have a pet** → Asks them to create one first
- Prevents errors when accessing pet features without owning a pet

---

## 🚨 Alert Badge System

The navigation bar displays **visual alerts** as colored badges to warn users about budget issues:

### Badge Types

#### 🔴 **RED BADGE - High Risk Alert**
- **Condition**: Budget spending **over 100%** (exceeding budget)
- **Location**: Top-right of Pet icon
- **Message**: "RED - Over 100%"
- **What it means**: You've spent more than your budget limit!

#### 🟠 **ORANGE BADGE - Caution Alert**
- **Condition**: Budget spending **70-99%** (approaching limit)
- **Location**: Top-right of Pet icon
- **Message**: "ORANGE - 70-99%"
- **What it means**: You're getting close to your budget limit!

#### ✅ **No Badge**
- **Condition**: Budget spending **below 70%**
- **What it means**: You're within safe spending limits

### Real-Time Updates

The badges update **automatically in real-time** using the `AlertStatusService`:
- No need to refresh the page
- Badges disappear/appear based on current budget status
- Works across all pages simultaneously

---

## 💾 Data & Dependencies

### What Data Gets Passed

When navigating, the component passes important user information:

```dart
- userId       → Identifies which user is logged in
- ledgerId     → Identifies which financial ledger to use
- currentIndex → Tracks which tab is currently active
```

### Database Queries

**Only for Pet navigation:**
```
Table: "Pet"
Query: Get user's pet ID
Purpose: Determine if user owns a pet
```

### Integrated Services

1. **AlertStatusService** → Real-time budget alert tracking
2. **Supabase Client** → Database queries for pet ownership
3. **Navigator** → Page transitions

---

## 🎨 Visual Design

### Colors

```
Selected Item Color    → Light Green (#A7E399) - Shows which tab is active
Background Color       → Light Yellow (#FEFFE3) - Soft, friendly appearance
Badge Colors          → Red (#D32F2F) or Orange (#F57C00)
```

### Layout

```
┌─────────────────────────────────────┐
│                                     │
│         Page Content Area           │
│                                     │
├─────────────────────────────────────┤
│  🏠    💳    🐾🔴  💰    ⚙️       │  ← Bottom Navigation Bar
│ Home Account Pet   Saving Settings  │
└─────────────────────────────────────┘
```

---

## ⚙️ Technical Implementation

### Component Structure

```
SharedBottomNavBar (StatelessWidget)
├── Properties
│   ├── currentIndex    → Current active tab
│   ├── userId          → User identifier
│   └── ledgerId        → Current ledger
│
├── Methods
│   ├── _handleNavigation()     → Routes navigation taps
│   ├── _handlePetNavigation()  → Special pet logic
│   └── _buildBadge()           → Creates alert badges
│
└── Build Method
    └── Returns BottomNavigationBar with badges
```

### Navigation Mapping

```
Index 0 → HomeScreen
Index 1 → AccountPage
Index 2 → PetNavigation (special logic)
Index 3 → SavingsPage
Index 4 → SettingsScreen
```

---

## 🔧 Error Handling

### What If Something Goes Wrong?

```
Pet Navigation Error
     ↓
Catches exception
     ↓
Shows error message:
"Error navigating to Pet: [error details]"
     ↓
User can try again
```

### Safety Features

✅ Prevents duplicate page loads (checks if already on page)  
✅ Catches database errors gracefully  
✅ Shows user-friendly error messages  
✅ Uses try-catch blocks for stability  

---

## 📊 Integration Points

### Where It's Used

This component appears on:
- ✅ Home Screen
- ✅ Account Management Page
- ✅ Pet Page
- ✅ Savings Goals Page
- ✅ Settings Page

### How It's Integrated

```dart
// In any main page's build method:
Scaffold(
  body: ... , // Page content
  bottomNavigationBar: SharedBottomNavBar(
    currentIndex: 0,           // Which tab to highlight
    userId: widget.userId,     // Pass user info
    ledgerId: widget.ledgerId, // Pass ledger info
  ),
)
```

---

## 🎯 User Journey Examples

### Example 1: Checking Budget Alert

```
1. User on Home Page
2. System detects budget spending at 75%
3. Orange badge appears on Pet icon
4. User notices warning immediately
5. User can tap on Account to check details
```

### Example 2: Creating a Pet

```
1. User taps Pet icon
2. System checks: "No pet found"
3. Redirects to PetMainPage
4. User creates new pet
5. Next time they tap Pet → Pet Home Page loads
```

### Example 3: Daily Workflow

```
1. User opens app → Home Page with navigation bar
2. Checks accounts → Taps Account tab
3. Updates savings goal → Taps Saving tab
4. Plays with pet → Taps Pet tab
5. Adjusts settings → Taps Setting tab
6. All tabs use same navigation bar for consistency
```

---

## 🚀 Key Features Summary

| Feature | Benefit |
|---------|---------|
| **5-Tab Navigation** | Quick access to all major app sections |
| **Smart Pet Logic** | Creates pet if needed, prevents errors |
| **Real-Time Alerts** | Users stay informed about budget status |
| **Consistent Design** | Same bar across all pages for familiarity |
| **Error Handling** | Gracefully handles problems |
| **Memory Efficient** | Replaces pages instead of stacking |

---

## 📝 Notes for Developers

### Important Points

1. **Always pass userId** → Required for database queries
2. **ledgerId is optional** → Used only in some pages
3. **currentIndex tracks active tab** → Updated when navigating
4. **Pet query only happens when tapping Pet** → Doesn't slow down other navigation
5. **Badges auto-update** → Don't need manual refresh

### If You Need to Modify

To add a new navigation item, you would:
1. Add new `BottomNavigationBarItem` to the list
2. Add new navigation case in `_handleNavigation()`
3. Import the new page class
4. Update index numbers accordingly

---

## 🎓 Summary

The **Shared Bottom Navigation Bar** is a **smart, reusable component** that:

✨ **Provides quick navigation** between 5 main app sections  
✨ **Handles special logic** for pet management  
✨ **Displays real-time alerts** about budget status  
✨ **Maintains consistency** across the entire app  
✨ **Prevents user errors** with validation and error handling  

It's essentially the **command center** of the entire FYP application, allowing users to navigate smoothly while staying informed about their financial status!

---

**Version**: 1.0  
**Last Updated**: April 2026  
**Component File**: `lib/widgets/shared_bottom_nav_bar.dart`
