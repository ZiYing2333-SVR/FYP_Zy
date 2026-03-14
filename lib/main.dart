import 'package:flutter/material.dart';
import 'package:fyp_wx/AIBuddy/ai_buddy_page.dart';
import 'package:fyp_wx/Challenge/View_Challenge.dart';
import 'package:fyp_wx/OCR/receipt_scan_page.dart';
import 'package:fyp_wx/pet/pet_main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'FacialRecognition/face_auth_service.dart';
import 'FacialRecognition/set_up_face_page.dart';
import 'FinancialTip/financial_tip_bottom_sheet.dart';
import 'Missions/missions_dropdown.dart';
import 'Missions/view_achievement.dart';
import 'Quiz/view_quiz_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://drohtvfhklvqoeokopey.supabase.co',
    anonKey: 'sb_publishable_G7rzmuNmAifrbXyuEFgbSg_PaKY75mW',
  );


  // await FaceAuthService.removeAllFaces();
  // await FaceAuthService.deleteFaceSet();
  await FaceAuthService.createFaceSet();

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Page',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: const Color(0xFFA7E399),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildButton(context, "Financial Tips"),
            _buildButton(context, "Quiz"),
            _buildButton(context, "AI Buddy"),

            _buildButton(context, "Missions"),
            _buildButton(context, "Achievement"),

            _buildButton(context, "Challenges"),

            _buildButton(context, "Budget Pet"),

            _buildButton(context, "Extract Receipt Data"),
            _buildButton(context, "Set Up Face ID"),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFA7E399),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          if (text == "Financial Tips") {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const FinancialTipBottomSheet(),
            );
          }else if (text == "Quiz") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ViewQuizPage(),
              ),
            );
          }else if (text == "AI Buddy") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AiBuddyPage(),
              ),
            );
          }else if (text == "Extract Receipt Data") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReceiptScanPage(),
              ),
            );
          }else if (text == "Missions") {
            showMissionDropdown(context);
          }else if (text == "Achievement") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AchievementPage(),
              ),
            );
          }else if (text == "Challenges") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ViewChallengePage(),
              ),
            );
          }else if (text == "Budget Pet") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PetMainPage(),
              ),
            );
          }else if (text == "Set Up Face ID") {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SetUpFacePage(),
              ),
            );
          }

        },


        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
