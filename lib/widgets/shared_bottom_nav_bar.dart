import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/alert_status_service.dart';
import '../screens/home_screen.dart';
import '../screens/account_page.dart';
import '../screens/savings_page.dart';
import '../screens/settings_screen.dart';
import '../pet/pet_main.dart';
import '../pet/pet_home_page.dart';

/// Shared bottom navigation bar widget used across all 4 main pages
/// Automatically syncs badge status via AlertStatusService
class SharedBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userId;
  final String? ledgerId;

  const SharedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.userId,
    this.ledgerId,
  });

  void _handleNavigation(BuildContext context, int index) {
    if (index == currentIndex) return; // Already on this page

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userId: userId)),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AccountPage(userId: userId)),
      );
    } else if (index == 2) {
      //PET LOGIC
      _handlePetNavigation(context);
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SavingsPage(userId: userId, ledgerId: ledgerId),
        ),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SettingsScreen(userId: userId)),
      );
    }
  }

  void _handlePetNavigation(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;

      // Check if user has a pet
      final petData = await supabase
          .from('Pet')
          .select('petId')
          .eq('userId', userId)
          .limit(1);

      if (petData.isNotEmpty) {
        // User has a pet, go to PetHomePage
        final petId = petData[0]['petId'];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetHomePage(petId: petId, userId: userId),
          ),
        );
      } else {
        // User doesn't have a pet, go to PetMainPage
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PetMainPage(userId: userId)),
        );
      }
    } catch (e) {
      print('Error navigating to Pet: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error navigating to Pet: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AlertStatusService().hasCautionAlertNotifier,
      builder: (context, hasCaution, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: AlertStatusService().hasHighRiskAlertNotifier,
          builder: (context, hasHighRisk, _) {
            return Stack(
              children: [
                BottomNavigationBar(
                  currentIndex: currentIndex,
                  selectedItemColor: const Color(0xFFA7E399),
                  backgroundColor: const Color(0xFFFEFFD3),
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.account_balance_wallet),
                      label: 'Account',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.pets),
                      label: 'Pet',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.savings),
                      label: 'Saving',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings),
                      label: 'Setting',
                    ),
                  ],
                  onTap: (index) {
                    _handleNavigation(context, index);
                  },
                ),
                // Build badges based on AlertStatusService (Budget icon at index 2)
                if (hasHighRisk)
                  _buildBadge(Colors.red.shade700, '!', 'RED - Over 100%')
                else if (hasCaution)
                  _buildBadge(Colors.orange.shade700, '⚠', 'ORANGE - 70-99%'),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBadge(Color color, String icon, String tooltip) {
    return Positioned(
      right: 12,
      top: 8,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
