import 'package:flutter/material.dart';
import 'package:fyp_wx/Missions/view_mission.dart';

/// CALL THIS FUNCTION TO SHOW DROPDOWN
void showMissionDropdown(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Mission",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 600),

    pageBuilder: (_, __, ___) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: _MissionContent(),
        ),
      );
    },

    transitionBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        )),
        child: child,
      );
    },
  );
}

/// DROPDOWN UI
class _MissionContent extends StatelessWidget {
  const _MissionContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.3,
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),

    child: Padding(
    padding: const EdgeInsets.only(top: 35),
    child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// IMAGE
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: Image.asset(
                'assets/images/mission.png',
                fit: BoxFit.contain,
              ),
            ),
          ),


          const SizedBox(width: 16),

          ///  TEXT + BUTTON
          Expanded(
            child: SizedBox(
              height: 150, //
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // center vertically
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// Line 1
                  const Text(
                    "Good Day!",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  /// Line 2
                  const Text(
                    "Your daily missions are ready.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// ROUNDED BUTTON
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA7E399),
                        padding:
                        const EdgeInsets.symmetric(horizontal: 20),

                        /// FULL ROUNDED (PILL)
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),

                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MissionPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "View Missions",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

